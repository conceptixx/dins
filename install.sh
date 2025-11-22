#!/bin/bash
set -e

# ==============================+++
# DINS INSTALLER - 3 PHASE SYSTEM
# ==============================

DEBUG=true
LOG_FILE="/home/pi/dins-install.log"
INSTALL_MARKER="/var/log/dins-install-complete"
PAUSE_FLAG="/var/log/dins-wait-for-tty"
SCRIPT_PATH="/home/pi/install.sh"
WAKE_UNIT="/etc/systemd/system/dins-wake.service"
RESUME_UNIT="/etc/systemd/system/dins-resume.service"
SCRIPT_URL="https://raw.githubusercontent.com/conceptixx/dins/main/install.sh"

# Save a persistent copy of this script if it doesn't already exist
if [ ! -f "$SCRIPT_PATH" ]; then
  echo "[DINS] Saving installer to $SCRIPT_PATH ..."
  curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
  sudo chmod +x "$SCRIPT_PATH"
  echo "[DINS] Installer persisted. Re-run with: sudo bash $SCRIPT_PATH"
fi
log() {
  local msg="$(date '+%Y-%m-%d %H:%M:%S') - $1"
  if [ "$DEBUG" = true ]; then
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
create_systemd_reboot() {
  log "[SYSTEMD] Creating wake unit for reboot phase..."
  {
    echo "[Unit]"
    echo "Description=DINS Wake Phase (After Reboot)"
    echo "After=network-online.target"
    echo "Wants=network-online.target"
    echo ""
    echo "[Service]"
    echo "Type=oneshot"
    echo "ExecStart=/bin/bash /usr/local/bin/resume.sh"
    echo "WorkingDirectory=/home/pi"
    echo "StandardOutput=journal+console"
    echo "StandardError=journal+console"
    echo "RemainAfterExit=no"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } | sudo tee "$WAKE_UNIT" > /dev/null
}
enable_systemd_reboot() {
  log "[SYSTEMD] Enabling wake unit..."
  sudo systemctl daemon-reexec
  sudo chmod 644 "$WAKE_UNIT"
  sudo systemctl daemon-reload
  sudo systemctl enable dins-wake.service > /dev/null
}
create_systemd_resume() {
  log "[SYSTEMD] Creating resume unit for next TTY login..."
  {
    echo "[Unit]"
    echo "Description=DINS Resume on SSH or Console Login"
    echo "After=multi-user.target"
    echo ""
    echo "[Service]"
    echo "Type=idle"
    echo "ExecStart=/bin/bash /home/pi/install.sh --resume"
    echo "StandardOutput=journal+console"
    echo "StandardError=journal+console"
    echo "RemainAfterExit=no"
    echo ""
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } | sudo tee $RESUME_UNIT > /dev/null
}
enable_systemd_resume() {
  log "[SYSTEMD] Disabling wake unit to prevent loop."
  sudo systemctl disable dins-wake.service > /dev/null
  log "[SYSTEMD] Enabling resume unit..."
  sudo systemctl daemon-reexec
  sudo chmod 644 "$RESUME_UNIT"
  sudo systemctl daemon-reload
  sudo systemctl enable dins-resume.service > /dev/null

}

create_systemd_wakeup() {
  log "[SYSTEMD] wake unit file created..."
  local resume_file="/usr/local/bin/resume.sh"
  {
    echo "#!/bin/bash"
    echo "# This script will wait for an SSH session and then resume the install"
    echo ""
    echo "sudo systemctl disable dins-wake.service > /dev/null"
    echo 'echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" >> "/home/pi/dins-install.log"'
    echo ""
    echo "echo \"[DINS] Waiting for SSH session to resume installation...\""
    echo ""
    echo "# Loop until a TTY is available"
    echo "while ! who | grep -q 'pts'; do"
    echo "sleep 2"
    echo "done"
    echo ""
    echo "# Once we have a TTY, run the resume function"
    echo 'sudo -u pi /usr/bin/script -q -c "/home/pi/install.sh --resume" /dev/null'
  } | sudo tee "$resume_file" >/dev/null
  sudo chmod 644 "$resume_file"

}
start_install() {
  local LOGSTAMP=$(date -u +"%Y%m%d_%H%M%SZ")
  log "---"
  log "--- started installation $LOGSTAMP"
  log "---"

#  up_raspi
#  prerequisites
#  inst_docker
#  enable_docker
  create_systemd_reboot
#  create_systemd_resume
  enable_systemd_reboot
  create_systemd_wakeup

# Prevent rerun loop on reboot
if systemctl is-active --quiet dins-wake.service; then
  echo "[DINS] Wake service active — exiting to prevent reboot loop."
  exit 0
else
  log "[REBOOT] Preparing to reboot now..."
  sudo reboot
fi
}

resume_install() {
  log "[RESUME] Resuming installation inside active TTY."

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
  --R|--resume)
    resume_install
    ;;
  *)
    start_install
    ;;
esac
