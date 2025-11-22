#!/usr/bin/env bash
# alternate
##!/bin/bash
# alternate
# set -euo pipefail # - regular
set -e

# ==============================
# DINS INSTALLER
# ==============================

DEBUG=true
LOG_FILE="/home/pi/dins-install.log"
SCRIPT_PATH="/home/pi/install.sh"
SCRIPT_URL="https://raw.githubusercontent.com/conceptixx/dins/main/install.sh"
NEXT_STATE=""

log() {
  local msg="$(date '+%Y-%m-%d %H:%M:%S') - $1"
  if [ "${DEBUG:-true}" = true ]; then
    echo "$msg" | tee -a "$LOG_FILE"
  else
    echo "$msg" >> "$LOG_FILE"
  fi
}

log "[START] Initial installation triggered."

up_raspi() {
  sudo apt-get update -qq -y > /dev/null
  sudo apt-get upgrade -qq -y > /dev/null
  log "[APT] System updated and upgraded."
  {
    echo "[OK] update and upgrade Raspberry Pi OS"
  } | sudo tee -a /tmp/motd.dins > /dev/null
  NEXT_STATE="[--] Installing Prerequisites"
}
prerequisites() {
  if apt-cache show software-properties-common > /dev/null 2>&1; then
    sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common > /dev/null
  else
    sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null
  fi
  log "[APT] Prerequisites installed."
  {
    echo "[OK] Prerequisites installed"
  } | sudo tee -a /tmp/motd.dins > /dev/null
  NEXT_STATE="[--] Installing Docker"
}
inst_docker() {
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq -y > /dev/null
  sudo apt-get install -qq -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
  log "[DOCKER] Docker installed successfully."
  {
    echo "[OK] Docker installed"
  } | sudo tee -a /tmp/motd.dins > /dev/null
  NEXT_STATE="[--] Enabling Docker"
}
enable_docker() {
  sudo systemctl enable docker > /dev/null
  sudo usermod -aG docker "$USER"
  log "[DOCKER] Docker enabled and user added to group."
  {
    echo "[OK] Docker enabled"
  } | sudo tee -a /tmp/motd.dins > /dev/null
  NEXT_STATE="[--] Initializing Docker Swarm"
}
start_install() {
  echo "[DINS] Installation started"
  echo "------------------------------------------------------------"
  # Save a persistent copy of this script if it doesn't already exist
  if [ ! -f "$SCRIPT_PATH" ]; then
    echo "[DINS] Saving installer to $SCRIPT_PATH ..."
    curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
    sudo chmod +x "$SCRIPT_PATH"
  fi
  # copy log in message
  sudo cp /etc/motd /etc/motd.backup
  sudo cp /etc/motd /tmp/motd.dins
  # create progress entries
  {
    echo ""
    echo "[DINS] Installation running ..."
  } | sudo tee -a /tmp/motd.dins > /dev/null
  # start log file
  local LOGSTAMP=$(date -u +"%Y%m%d_%H%M%SZ")
  log "---"
  log "--- started installation $LOGSTAMP"
  log "---"
}
run_reboot() {
  log "[REBOOT] Preparing to reboot now..."
  sudo cp /tmp/motd.dins /etc/motd
  {
    echo "${NEXT_STATE}"
    echo ""
    echo 'To continue run "sudo ./install.sh"'
  } | sudo tee -a /etc/motd > /dev/null
  sudo reboot
}
init_docker_swarm() {
  if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
    IP_ADDR=$(get_advertise_addr)
    log "[SWARM] Initializing Docker Swarm on $IP_ADDR ..."
    sudo docker swarm init --advertise-addr "$IP_ADDR" || true
  else
    log "[SWARM] Docker Swarm already active."
  fi
  {
    echo "[OK] Docker Swarm initialized"
  } | sudo tee -a /tmp/motd.dins > /dev/null
  NEXT_STATE="[--] Pull Docker Setup Image"
}
pull_setup_image() {
  if docker image inspect install:local > /dev/null 2>&1; then
    IMAGE_NAME="install:local"
  else
    IMAGE_NAME="ghcr.io/conceptixx/install:latest"
    sudo docker pull $IMAGE_NAME
    log "[IMAGE] Pulled GHCR: $IMAGE_NAME"
  fi
  {
    echo "[OK] Docker Setup Image pulled"
  } | sudo tee -a /tmp/motd.dins > /dev/null
  NEXT_STATE="[--] Running Setup Image"
}
run_setup_image() {
  sudo docker run -d --name dins-installer --restart unless-stopped \\
    --mount type=bind,src=/srv/docker/services,dst=/mnt/dins \\
    $IMAGE_NAME
  {
    echo "[OK] Run Docker Setup Image"
  } | sudo tee -a /tmp/motd.dins > /dev/null
  NEXT_STATE="[--] Setup DINS System"
}
run_install_completed() {
  sudo mv /tmp/motd.backup /etc/motd
  sudo rm /tmp/motd.backup
  sudo rm /tmp/motd.dins
}
get_advertise_addr() {
  # Try to detect Ethernet (eth0) first
  if ip link show eth0 2>/dev/null | grep -q "state UP"; then
    ETH_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    if [ -n "$ETH_IP" ]; then
      log "[NETWORK] Ethernet connected. Using $ETH_IP (eth0)"
      echo "$ETH_IP"
      return
    fi
  fi

  # Fallback: use Wi-Fi IPv4
  WLAN_IP=$(ip -4 addr show wlan0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
  if [ -n "$WLAN_IP" ]; then
    log "[NETWORK] Using Wi-Fi IP $WLAN_IP (wlan0)"
    echo "$WLAN_IP"
    return
  fi

  # Fallback: hostname IPv4
  HOST_IP=$(hostname -I | awk '{print $1}')
  log "[NETWORK] Defaulting to $HOST_IP (hostname -I)"
  echo "$HOST_IP"
}

main() {
  while true; do
    case $(cat ./state 2>/dev/null | xargs) in
      up_raspi)
        echo "prerequisites" > ./state
        up_raspi
        ;;
      prerequisites)
        echo "inst_docker" > ./state
        prerequisites
        ;;
      inst_docker)
        echo "enable_docker" > ./state
        inst_docker
        ;;
      enable_docker)
        echo "docker_reboot" > ./state
        prerequisites
        ;;
      docker_reboot)
        echo "init_docker_swarm" > ./state
        run_reboot
        break
        ;;
      init_docker_swarm)
        echo "pull_setup_image" > ./state
        init_docker_swarm
        ;;
      pull_setup_image)
        echo "run_setup_image" > ./state
        pull_setup_image
        ;;
      run_setup_image)
        echo "setup_complete" > ./state
        run_setup_image
        ;;
      run_install_completed)
        run_install_completed
        break
        ;;
      *)
        # first call
        echo "up_raspi" > ./state
        start_install
        ;;
    esac
  done
}

main


