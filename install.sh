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

log() {
  if [ "$DEBUG" = true ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
  fi
}

log "[START] Initial installation triggered."

start_install() {
  local LOGSTAMP=$(date -u +"%Y%m%d_%H%M%SZ")
  log "---"
  log "--- started installation $LOGSTAMP"
  log "---"

  up_raspi() {
    sudo apt-get update -qq -y > /dev/null
    sudo apt-get upgrade -qq -y > /dev/null
    log "[APT] System updated and upgraded."
  }
  prerequisites() {
    if apt-cache show software-properties-common > /dev/null 2>&1; then
      sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common > /dev/null
    else
      sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null
    fi
    log "[APT] Prerequisites installed."
  }
  inst_docker() {
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -qq -y > /dev/null
    sudo apt-get install -qq -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
    log "[DOCKER] Docker installed successfully."
  }
  enable_docker() {
    sudo systemctl enable docker > /dev/null
    sudo usermod -aG docker "$USER"
    log "[DOCKER] Docker enabled and user added to group."
  }
  enable_systemd() {
    log "[SYSTEMD] Creating wake unit for reboot phase..."
    {
      echo "[Unit]"
      echo "Description=DINS Wake Phase (After Reboot)"
      echo "After=network-online.target"
      echo "Wants=network-online.target"
      echo ""
      echo "[Service]"
      echo "Type=oneshot"
      echo "User=pi"
      echo "ExecStart=/bin/bash \"$SCRIPT_PATH\" --wake"
      echo "WorkingDirectory=/home/pi"
      echo "StandardOutput=journal+console"
      echo "StandardError=journal+console"
      echo "RemainAfterExit=no"
      echo ""
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } | sudo tee "$WAKE_UNIT" > /dev/null
    sudo systemctl daemon-reexec
    chmod 644 dins-wake.service
    sudo systemctl daemon-reload
    sudo systemctl enable dins-wake.service > /dev/null
  }

#  up_raspi
#  prerequisites
#  inst_docker
#  enable_docker
  enable_systemd

  log "[REBOOT] Preparing to reboot now..."
  sudo touch "$PAUSE_FLAG"
  sudo reboot
}

reboot_pause() {
  log "[WAKE] System rebooted and wake phase triggered."

  if [ -f "$INSTALL_MARKER" ]; then
    log "[WAKE] Installation already marked as complete. Aborting wake phase."
    exit 0
  fi

  log "[SYSTEMD] Disabling wake unit to prevent loop."
  sudo systemctl disable dins-wake.service > /dev/null

  log "[SYSTEMD] Creating resume unit for next TTY login..."
  {
    echo "[Unit]"
    echo "Description=DINS Resume on SSH or Console Login"
    echo "After=multi-user.target"
    echo ""
    echo "[Service]"
    echo "Type=idle"
    echo "ExecStart=/bin/bash $SCRIPT_PATH --resume"
    echo "StandardOutput=journal+console"
    echo "StandardError=journal+console"
    echo "RemainAfterExit=no"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } | sudo tee $RESUME_UNIT > /dev/null

  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable dins-resume.service > /dev/null

  log "[WAKE] Resume service ready. Waiting for SSH/TTY login..."
  exit 0
}

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

  sudo docker run -d --name dins-installer --restart unless-stopped \\
    --mount type=bind,src=/srv/docker/services,dst=/mnt/dins \\
    $IMAGE_NAME

  log "[COMPLETE] Installation done. Marking complete."
  sudo touch "$INSTALL_MARKER"
}

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
