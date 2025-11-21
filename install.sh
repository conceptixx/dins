#!/bin/bash
set -e

INSTALL_MARKER="/var/log/dins-install-complete"
PAUSE_FLAG="/var/log/dins-wait-for-tty"
SCRIPT_PATH="/home/pi/install.sh"

function start_install() {
  echo "[DINS] Starting initial installation phase..."

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

  echo "[DINS] Preparing reboot and wake service..."
  reboot_pause
}

function reboot_pause() {
  sudo touch "$PAUSE_FLAG"

  echo "[DINS] Creating systemd wake service..."
  cat <<EOF | sudo tee /etc/systemd/system/dins-wake.service > /dev/null
[Unit]
Description=DINS Wake and Resume after Reboot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $SCRIPT_PATH --wake
StandardOutput=journal+console
StandardError=journal+console
TTYPath=/dev/tty1
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable dins-wake.service > /dev/null

  echo "[DINS] System will reboot now to apply Docker group changes..."
  sudo reboot
}

function resume_install() {
  echo "[DINS] Resuming installation..."
  sudo rm -f "$PAUSE_FLAG"

  echo "[DINS] Checking Docker Swarm status..."
  if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
    echo "[DINS] Initializing Docker Swarm..."
    sudo docker swarm init || true
  else
    echo "[DINS] Docker Swarm already active."
  fi

  echo "[DINS] Pulling local install image or falling back to GHCR..."
  if docker image inspect install:local > /dev/null 2>&1; then
    IMAGE_NAME="install:local"
  else
    IMAGE_NAME="ghcr.io/conceptixx/install:latest"
    sudo docker pull $IMAGE_NAME
  fi

  echo "[DINS] Running installer container..."
  sudo docker run -d --name dins-installer --restart unless-stopped \
    --mount type=bind,src=/srv/docker/services,dst=/mnt/dins \
    $IMAGE_NAME

  echo "[DINS] Installation complete."
  sudo touch "$INSTALL_MARKER"
  sudo systemctl disable dins-wake.service > /dev/null
}

# === Argument Parser ===
case "$1" in
  --W|--wake)
    echo "[DINS] Wake event triggered after reboot..."
    if [ -f "$PAUSE_FLAG" ]; then
      echo "[DINS] Waiting for SSH or TTY login to continue..."
      cat <<'EOF' | sudo tee /etc/profile.d/dins-resume.sh > /dev/null
#!/bin/bash
if [ -f /var/log/dins-wait-for-tty ]; then
  echo "[DINS] Reboot complete - installation continues..."
  /home/pi/install.sh --resume
  sudo rm -f /etc/profile.d/dins-resume.sh
fi
EOF
      sudo chmod +x /etc/profile.d/dins-resume.sh
    fi
    ;;
  --R|--resume)
    resume_install
    ;;
  *)
    start_install
    ;;
esac
