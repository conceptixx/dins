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
SIMULATE=false

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
  if [ ! -f /etc/motd.backup ]; then
    sudo cp /etc/motd /etc/motd.backup
  fi
  sudo cp /etc/motd.backup /tmp/motd.dins
  sudo cp /etc/motd.backup /etc/motd
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
run_reboot_docker() {
  log "[REBOOT] Preparing to reboot now..."
  sudo cp /tmp/motd.dins /etc/motd
  {
    echo "${NEXT_STATE}"
    echo ""
    echo 'To continue run "\033[1;33msudo ./install.sh\033[0m"'
    echo ""
    echo "usage:"
    echo "    --S          | simulate installation for not container components"
    echo "    --C          | enables console for configuration"
    echo "    --W          | enables webUI for configuration"
    echo "    --C --E      | enables and launches console configuration"
    echo "    --W --C --E  | enables webUI and console and launches console config"
    echo "    --W --C      | enables webUi and console configuration"
  } | sudo tee -a /etc/motd > /dev/null
  sync
  sudo reboot
}
run_reboot() {
  log "[REBOOT] Preparing to reboot now..."
  sudo cp /tmp/motd.dins /etc/motd
  {
    echo "${NEXT_STATE}"
    echo ""
    echo 'To continue run "sudo ./install.sh"'
  } | sudo tee -a /etc/motd > /dev/null
  sync
  sudo reboot
}
init_docker_swarm() {
  if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
    IP_ADDR=$(get_advertise_addr | tail -n1 | xargs)
    if [[ -z "$IP_ADDR" ]]; then
      log "[ERROR] No valid IP found for Docker Swarm. Skipping initialization."
      {
        echo "[XX] No valid IP found for Docker Swarm. Skipping initialization"
      } | sudo tee -a /tmp/motd.dins > /dev/null
      echo "init_docker_swarm" > ./state
      return 1
    fi
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
  local LOCAL_IMAGE="dins-setup:local"
  local REMOTE_IMAGE="ghcr.io/conceptixx/dins-setup:latest"

  # Prefer local build if available
  if docker image inspect "$LOCAL_IMAGE" > /dev/null 2>&1; then
    IMAGE_NAME="$LOCAL_IMAGE"
    log "[IMAGE] Using local setup image: $LOCAL_IMAGE"
  else
    IMAGE_NAME="$REMOTE_IMAGE"
    if ! sudo docker image inspect "$REMOTE_IMAGE" > /dev/null 2>&1; then
      log "[IMAGE] Pulling setup image: $REMOTE_IMAGE"
      sudo docker pull --disable-content-trust=true "$REMOTE_IMAGE"
      log "[IMAGE] Setup image pulled successfully."
    else
      log "[IMAGE] Setup image already present locally."
    fi
  fi

  {
    echo "[OK] Docker Setup Image ready ($IMAGE_NAME)"
  } | sudo tee -a /tmp/motd.dins > /dev/null

  NEXT_STATE="[--] Running Setup Image"
}
run_setup_image() {
  IMAGE_NAME=${IMAGE_NAME:-"ghcr.io/conceptixx/dins-setup:latest"}
  log "[DOCKER] Starting main DINS installer container..."

  # Ensure bind mount exists
  if [ ! -d "/srv/docker/services" ]; then
    log "[FS] Creating /srv/docker/services ..."
    sudo mkdir -p /srv/docker/services
    sudo chmod 777 /srv/docker/services
  fi

  # Clean up any old container
  if sudo docker ps -a --format '{{.Names}}' | grep -q '^dins-setup$'; then
    log "[DOCKER] Removing existing dins-setup container..."
    sudo docker stop dins-setup >/dev/null 2>&1 || true
    sudo docker rm dins-setup >/dev/null 2>&1 || true
  fi

  # If console mode is enabled, run interactively
  if [ "$ENABLE_CONSOLE" = true ]; then
    log "[MODE] Console mode active — attaching container output."
    sudo docker run --rm -it \
      --name dins-setup \
      --mount type=bind,src=/srv/docker/services,dst=/mnt/dins \
      -e SIMULATE="$SIMULATE" \
      -e ENABLE_WEBUI="$ENABLE_WEBUI" \
      -e ENABLE_CONSOLE="$ENABLE_CONSOLE" \
      -e AUTO_EXECUTE="$AUTO_EXECUTE" \
      "$IMAGE_NAME"
  else
    # Detached mode (background)
    sudo docker run -d --name dins-setup --restart unless-stopped \
      --mount type=bind,src=/srv/docker/services,dst=/mnt/dins \
      -e SIMULATE="$SIMULATE" \
      -e ENABLE_WEBUI="$ENABLE_WEBUI" \
      -e ENABLE_CONSOLE="$ENABLE_CONSOLE" \
      -e AUTO_EXECUTE="$AUTO_EXECUTE" \
      "$IMAGE_NAME" || {
        log "[WARN] Installer container already running."
      }
  fi

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
  # Try Ethernet first
  ETH_IP=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
  if [[ -n "$ETH_IP" ]]; then
    log "[NETWORK] Ethernet connected. Using $ETH_IP (eth0)"
    echo "$ETH_IP"
    return
  fi

  # Then Wi-Fi
  WLAN_IP=$(ip -4 addr show wlan0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
  if [[ -n "$WLAN_IP" ]]; then
    log "[NETWORK] Using Wi-Fi IP $WLAN_IP (wlan0)"
    echo "$WLAN_IP"
    return
  fi

  # Finally fallback to hostname -I
  HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -n "$HOST_IP" ]]; then
    log "[NETWORK] Falling back to hostname IP $HOST_IP"
    echo "$HOST_IP"
    return
  fi

  # If nothing found, stop script safely
  log "[ERROR] No network IP found! Aborting Swarm init."
  echo ""
  return 1
}

main() {
  if [[ "${1:-}" =~ (--S|--simulate) ]]; then
    SIMULATE=true
  fi

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
        run_reboot_docker
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
        run_setup_image $SIMULATE
        ;;
      setup_complete)
        echo "run_setup_image" > ./state
        break
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


