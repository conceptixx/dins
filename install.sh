#!/bin/bash
set -e

LOG_FILE="/home/pi/dins-install.log"
INSTALL_MARKER="/var/log/dins-install-complete"
PAUSE_FLAG="/var/log/dins-wait-for-tty"
SCRIPT_PATH="/home/pi/install.sh"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

log "install.sh started"

function start_install() {
  log "[START] Starting initial installation phase..."

  sudo apt-get update -qq -y > /dev/null
  sudo apt-get upgrade -qq -y > /dev/null
  log "[APT] System update and upgrade complete."

  if apt-cache show software-properties-common > /dev/null 2>&1; then
    sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common > /dev/null
  else
    sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null
  fi
  log "[APT] Docker prerequisites installed."

  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  log "[DOCKER] GPG key added."

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -qq -y > /dev/null
  sudo apt-get install -qq -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
  log "[DOCKER] Docker installed successfully."

  sudo systemctl enable docker > /dev/null
  sudo usermod -aG docker $USER
  log "[SYSTEM] Docker enabled and user added to docker group."

  reboot_pause
}

function reboot_pause() {
  log "[PAUSE] Entering pause mode and creating systemd wake service..."
  sudo touch "$PAUSE_FLAG"

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
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable dins-wake.service > /dev/null
  log "[REBOOT] Reboot initiated..."
  sudo reboot
}

function resume_install() {
  log "[RESUME] Resuming installation..."
  sudo rm -f "$PAUSE_FLAG"

  if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
    log "[SWARM] Initializing Docker Swarm..."
    sudo docker swarm init || true
  else
    log "[SWARM] Docker Swarm already active."
  fi

  if docker image inspect install:local > /dev/null 2>&1; then
    IMAGE_NAME="install:local"
  else
    IMAGE_NAME="ghcr.io/conceptixx/install:latest"
    sudo docker pull $IMAGE_NAME
    log "[IMAGE] Pulled from GHCR: $IMAGE_NAME"
  fi

  sudo docker run -d --name dins-installer --restart unless-stopped \
    --mount type=bind,src=/srv/docker/services,dst=/mnt/dins \
    $IMAGE_NAME

  log "[COMPLETE] DINS installation completed successfully."
  sudo touch "$INSTALL_MARKER"
  sudo systemctl disable dins-wake.service > /dev/null
}

case "$1" in
  --W|--wake)
    log "[WAKE] System rebooted, preparing TTY resume..."
    if [ -f "$PAUSE_FLAG" ]; then
      cat <<'EOF' | sudo tee /etc/profile.d/dins-resume.sh > /dev/null
#!/bin/bash
if [ -f /var/log/dins-wait-for-tty ]; then
  echo "[DINS] Reboot complete - installation continues..."
  /home/pi/install.sh --resume
  sudo rm -f /etc/profile.d/dins-resume.sh
fi
EOF
      sudo chmod +x /etc/profile.d/dins-resume.sh
      log "[WAKE] Resume hook added in /etc/profile.d/"
    fi
    ;;
  --R|--resume)
    log "[RESUME] TTY capture triggered."
    resume_install
    ;;
  *)
    start_install
    ;;
esac
