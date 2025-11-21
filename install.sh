#!/bin/bash
set -e

# ==============================
# DINS INSTALLER - 3 PHASE SYSTEM
# ==============================

DEBUG=true
LOG_FILE="/home/pi/dins-install.log"
INSTALL_MARKER="/var/log/dins-install-complete"
PAUSE_FLAG="/var/log/dins-wait-for-tty"
SCRIPT_PATH="/home/pi/install.sh"
WAKE_UNIT="/etc/systemd/system/dins-wake.service"
RESUME_UNIT="/etc/systemd/system/dins-resume.service"

# Logging function (only logs if DEBUG=true)
log() {
  if [ "$DEBUG" = true ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
  fi
}

# ==============================
# FUNCTION: start_install
# ==============================
start_install() {
  log "[START] Initial installation triggered."

  sudo apt-get update -qq -y > /dev/null
  sudo apt-get upgrade -qq -y > /dev/null
  log "[APT] System updated and upgraded."

  if apt-cache show software-properties-common > /dev/null 2>&1; then
    sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common > /dev/null
  else
    sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null
  fi
  log "[APT] Prerequisites installed."

  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -qq -y > /dev/null
  sudo apt-get install -qq -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
  log "[DOCKER] Docker installed successfully."

  sudo systemctl enable docker > /dev/null
  sudo usermod -aG docker "$USER"
  log "[DOCKER] Docker enabled and user added to group."

  log "[SYSTEMD] Creating wake unit for reboot phase..."
  sudo bash -c "cat > $WAKE_UNIT <<EOF
[Unit]
Description=DINS Wake Phase (After Reboot)
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
EOF"
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable dins-wake.service > /dev/null

  log "[REBOOT] Preparing to reboot now..."
  sudo touch "$PAUSE_FLAG"
  sudo reboot
}

# ==============================
# FUNCTION: reboot_pause
# ==============================
reboot_pause() {
  log "[WAKE] System rebooted and wake phase triggered."

  # Prevent infinite loop
  if [ -f "$INSTALL_MARKER" ]; then
    log "[WAKE] Installation already marked as complete. Aborting wake phase."
    exit 0
  fi

  log "[SYSTEMD] Disabling wake unit to prevent loop."
  sudo systemctl disable dins-wake.service > /dev/null

  log "[SYSTEMD] Creating resume unit for next TTY login..."
  sudo bash -c "cat > $RESUME_UNIT <<EOF
[Unit]
Description=DINS Resume on SSH or Console Login
After=multi-user.target

[Service]
Type=idle
ExecStart=/bin/bash $SCRIPT_PATH --resume
StandardOutput=journal+console
StandardError=journal+console
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF"
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable dins-resume.service > /dev/null

  log "[WAKE] Resume service ready. Waiting for SSH/TTY login..."
  exit 0
}

# ==============================
# FUNCTION: resume_install
# ==============================
resume_install() {
  log "[RESUME] Resuming installation inside active TTY."

  sudo systemctl disable dins-resume.service > /dev/null
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
    log "[IMAGE] Pulled GHCR: $IMAGE_NAME"
  fi

  sudo docker run -d --name dins-installer --restart unless-stopped \
    --mount type=bind,src=/srv/docker/services,dst=/mnt/dins \
    $IMAGE_NAME

  log "[COMPLETE] Installation done. Marking complete."
  sudo touch "$INSTALL_MARKER"
}

# ==============================
# MAIN EXECUTION LOGIC
# ==============================
case "$1" in
  --W|--wake)
    reboot_pause
    ;;
  --R|--resume)
    resume_install
    ;;
  *)
    start_install
    ;;
esac
