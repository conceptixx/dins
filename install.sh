#!/bin/bash
set -e

INSTALL_MARKER="/var/log/dins-install-complete"

if [ -f "$INSTALL_MARKER" ]; then
  echo "[DINS] Setup already completed. Skipping..."
  exit 0
fi

echo "[DINS] Updating and upgrading Raspberry Pi OS..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "[DINS] Installing Docker prerequisites..."
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

echo "[DINS] Enabling Docker on boot..."
sudo systemctl enable docker
sudo usermod -aG docker $USER

echo "[DINS] Creating systemd unit to resume setup after reboot..."
SERVICE_NAME="dins-continue-install"

cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null
[Unit]
Description=DINS Resume Installation
After=multi-user.target

[Service]
Type=simple
ExecStart=/bin/bash /home/pi/install.sh
StandardOutput=journal
StandardError=journal
Restart=no

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

echo "[DINS] Rebooting to apply Docker group changes..."
sudo reboot
