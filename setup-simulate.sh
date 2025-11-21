#!/bin/bash
set -e

INSTALLER_IMAGE="ghcr.io/youruser/pi-setup-installer:latest"
PROJECT_DIR="$HOME/agent-setup"

# === Ensure Docker is installed ===
echo "[SETUP] Updating Raspberry Pi..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "[SETUP] Installing Docker..."
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# === Run installer container in simulate mode ===
echo "[SIMULATE] Pulling installer image: $INSTALLER_IMAGE"
docker pull "$INSTALLER_IMAGE"

echo "[SIMULATE] Running simulated setup in container..."
docker run -it --rm \
  --name simulate-installer \
  --hostname simulate-installer \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PROJECT_DIR":/mnt/project \
  "$INSTALLER_IMAGE"