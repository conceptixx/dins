#!/bin/bash
set -e

INSTALL_MARKER="/var/log/dins-install-complete"
PAUSE_FLAG="/var/log/dins-wait-for-tty"

if [ -f "$INSTALL_MARKER" ]; then
  echo "[DINS] Setup already completed. Skipping..."
  exit 0
fi

if [ -f "$PAUSE_FLAG" ]; then
  echo "[DINS] Reboot complete - installation continues..."
  read -p "[DINS] Press ENTER to continue setup..." CONTINUE
  rm -f "$PAUSE_FLAG"
fi

echo "[DINS] Updating and upgrading Raspberry Pi OS silently..."
sudo apt-get update -qq -y > /dev/null
sudo apt-get upgrade -qq -y > /dev/null

echo "[DINS] Installing Docker prerequisites silently..."
if apt-cache show software-properties-common > /dev/null 2>&1; then
  sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common > /dev/null
else
  sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null
fi

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -qq -y > /dev/null
sudo apt-get install -qq -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null

echo "[DINS] Enabling Docker on boot..."
sudo systemctl enable docker > /dev/null
sudo usermod -aG docker $USER

echo "[DINS] Creating pause marker for post-reboot resume..."
sudo touch "$PAUSE_FLAG"

echo "[DINS] Creating systemd service to resume setup..."
cat <<EOF | sudo tee /etc/systemd/system/dins-resume-install.service > /dev/null
[Unit]
Description=DINS Resume Installation After Reboot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash /home/pi/install.sh
StandardOutput=journal+console
StandardError=journal+console
Restart=no

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable dins-resume-install > /dev/null

echo "[DINS] Rebooting to apply Docker group changes..."
sudo reboot
