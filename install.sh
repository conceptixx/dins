#!/bin/bash
set -e

echo "[DINS] Updating and upgrading Raspberry Pi OS..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "[DINS] Installing Docker prerequisites..."

# Check if software-properties-common is available in the package list
if apt-cache show software-properties-common > /dev/null 2>&1; then
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common
else
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
fi

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[DINS] Enabling Docker to start on boot..."
sudo systemctl enable docker
sudo usermod -aG docker $USER

echo "[DINS] Initializing Docker Swarm..."
if ! docker info | grep -q 'Swarm: active'; then
  docker swarm init
else
  echo "[DINS] Swarm already active."
fi

echo "[DINS] Pulling local install image or falling back to GHCR..."
if docker image inspect install:local > /dev/null 2>&1; then
  IMAGE_NAME="install:local"
else
  IMAGE_NAME="ghcr.io/conceptixx/install:latest"
  docker pull $IMAGE_NAME
fi

echo "[DINS] Running installer container..."
docker run -d --name dins-installer --restart unless-stopped \
  --mount type=bind,src=/srv/docker/services,dst=/mnt/dins \
  $IMAGE_NAME
