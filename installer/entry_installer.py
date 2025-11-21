#!/usr/bin/env python3
import os
import subprocess
import re
import socket
import time

def get_hostname():
    return socket.gethostname()

def scan_network_for(prefix="dins-node", start=1, end=99):
    found = set()
    for i in range(start, end+1):
        host = f"{prefix}{i:02d}"
        try:
            subprocess.check_output(["ping", "-c", "1", "-W", "1", host], stderr=subprocess.DEVNULL)
            found.add(host)
        except subprocess.CalledProcessError:
            continue
    return found

def run_command(command, sudo=False):
    if sudo:
        command = ["sudo"] + command
    result = subprocess.run(command, capture_output=True, text=True)
    return result.stdout.strip()

def recommend_name(current_hostname):
    if current_hostname.startswith("dins-"):
        return current_hostname

    print("[INFO] Current hostname does not follow DINS convention.")
    network_nodes = scan_network_for()
    if "dins-master" not in network_nodes:
        return "dins-master"

    for i in range(1, 100):
        node_name = f"dins-node{i:02d}"
        if node_name not in network_nodes:
            return node_name
    return None

def set_hostname(new_name):
    print(f"[INFO] Setting hostname to {new_name}")
    run_command(["hostnamectl", "set-hostname", new_name], sudo=True)

def upgrade_os():
    print("[SETUP] Updating and upgrading Raspberry Pi OS...")
    run_command(["apt-get", "update", "-y"], sudo=True)
    run_command(["apt-get", "upgrade", "-y"], sudo=True)

def install_docker():
    print("[SETUP] Installing Docker...")
    run_command(["apt-get", "install", "-y",
                 "apt-transport-https", "ca-certificates", "curl", "gnupg", "lsb-release"], sudo=True)

    run_command(["mkdir", "-p", "/etc/apt/keyrings"], sudo=True)
    run_command(["bash", "-c",
                 "curl -fsSL https://download.docker.com/linux/debian/gpg | "
                 "gpg --dearmor -o /etc/apt/keyrings/docker.gpg"], sudo=True)

    lsb = run_command(["lsb_release", "-cs"])
    docker_repo = f"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] "                   f"https://download.docker.com/linux/debian {lsb} stable"
    run_command(["bash", "-c", f"echo '{docker_repo}' > /etc/apt/sources.list.d/docker.list"], sudo=True)
    run_command(["apt-get", "update", "-y"], sudo=True)
    run_command(["apt-get", "install", "-y", "docker-ce", "docker-ce-cli", "containerd.io", "docker-compose-plugin"], sudo=True)

def init_or_join_swarm():
    hostname = get_hostname()
    if hostname == "dins-master":
        print("[SWARM] Initializing Docker Swarm on master...")
        run_command(["docker", "swarm", "init"], sudo=True)
    else:
        print("[SWARM] Attempting to join swarm...")
        master_ip = run_command(["getent", "hosts", "dins-master"]).split()[0]
        token = run_command(["docker", "swarm", "join-token", "-q", "manager"], sudo=True)
        run_command(["docker", "swarm", "join", "--token", token, f"{master_ip}:2377"], sudo=True)

def pull_main_installer():
    print("[INSTALLER] Checking for local 'main-installer:local' image...")
    local_images = run_command(["docker", "images", "--format", "{{.Repository}}:{{.Tag}}"])
    if "main-installer:local" in local_images:
        print("[INSTALLER] Local image found.")
    else:
        print("[INSTALLER] Pulling image from GHCR...")
        run_command(["docker", "pull", "ghcr.io/conceptixx/main-installer:latest"])

def run_main_installer():
    print("[INSTALLER] Launching main-installer service...")
    run_command([
        "docker", "service", "create",
        "--name", "main_installer",
        "--mode", "global",
        "--mount", "type=bind,src=/srv/docker/services,dst=/mnt/dins",
        "ghcr.io/conceptixx/main-installer:latest"
    ])

def main():
    hostname = get_hostname()
    recommended = recommend_name(hostname)
    if hostname != recommended:
        print(f"[NOTICE] Recommended hostname: {recommended}")
        set_hostname(recommended)
        print("[INFO] Reboot required to apply hostname change.")
        return

    upgrade_os()
    install_docker()
    init_or_join_swarm()
    pull_main_installer()
    run_main_installer()

if __name__ == "__main__":
    main()
