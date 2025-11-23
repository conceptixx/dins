#!/usr/bin/env bash
# alternate
##!/bin/bash
# alternate
# set -euo pipefail # - regular
set -e
# ==============================
# --- paths
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"
SETUP_PATH="/srv/docker/services/setup"
BOOTSTRAP_PATH="/tmp/etc/dins/setup"
# --- files
SCRIPT_FILE="$(readlink -f "$0")"
LOG_FILE="${SCRIPT_PATH}/dins-install.log"
STATE_FILE="${SCRIPT_PATH}/STATE"
# --- variables
NEXT_STATE=""
REPO_URL="https://raw.githubusercontent.com/conceptixx/dins/main"
BOOTSTRAP_URL="${REPO_URL}/bootstrap"
SCRIPT_URL="${REPO_URL}/install.sh"
IS_SIMULATED="false"
# ==============================
# --- __log()
__log() {
  local MODE="${2:-append}"
  local LOG_MSG="$(date '+%Y-%m-%d %H:%M:%S') - $1"
  case "$MODE" in
    open) echo "$LOG_MSG" > "$LOG_FILE" ;;
    append) echo "$LOG_MSG" >> "$LOG_FILE" ;;
  esac
}
# --- __exec_mkdir()
__exec_mkdir() {
  local key="$1"
  local path="$2"
  # check if base or path (path can be /tmp prefixed)
  case $key in
    path)
      path="${IS_SIMULATED:+/tmp}$path"
      ;;
    base)
      ;;
  esac
  if [ -d "$path" ]; then
    __log "[MKDIR:$SUBMODE] directory exists: $path"
  else
    sudo mkdir -p "$path"
    if [ $? -eq 0 ]; then
      __log "[MKDIR:$SUBMODE] Created directory: $path"
    else
      __log "[MKDIR:$SUBMODE] failed to create: $path"
      return 1
    fi
  fi
}
# --- __exec_service()
__exec_service() {
  local key="$1"
  local svc="$2"
  __log "[SERVICE:$SUBMODE] Register service: $svc"
  echo "$svc" >> "$BOOTSTRAP_PATH/services.list"
}
# --- __exec_copy()
__exec_copy() {
  local src="$1"
  local dst="$2"
  sudo cp -r "$src" "$dst"
  __log "[COPY:$SUBMODE] Copied $src to $dst"
}
# --- __boot_msg()
__boot_msg() {
  local MSGMODE="$1"
  local ADDMSG="${1:-false}"
  local MSGFILE=/tmp/motd.dins
  local OUTFILE=/etc/motd
  case $MSGMODE in
    post)
      {
        echo "$ADDMSG"
      } | sudo tee -a "$MSGFILE" > /dev/null
      ;;
    boot)
      sudo cp /tmp/motd.dins /etc/motd
      {
        echo "${NEXT_STATE}"
        echo ""
        echo 'To continue run "sudo ./install.sh"'
        echo ""
        echo "usage:"
        echo "    --S          | simulate installation for not container components"
        echo "    --C          | enables console for configuration"
        echo "    --W          | enables webUI for configuration"
        echo "    --C --E      | enables and launches console configuration"
        echo "    --W --C --E  | enables webUI and console and launches console config"
        echo "    --W --C      | enables webUi and console configuration"
      } | sudo tee -a "$OUTFILE" > /dev/null
      ;;
    init)
      # copy log in message as backup
      if [ ! -f /etc/motd.backup ]; then
        sudo cp /etc/motd /etc/motd.backup
      fi
      # copy backup to tmp motd.dins
      sudo cp /etc/motd.backup /tmp/motd.dins
      # copy backup to motd
      sudo cp /etc/motd.backup /etc/motd
      {
        echo "\n[DINS] Installation running ..."
      } | sudo tee -a "$MSGFILE" > /dev/null
      ;;
    close)
      # restore backup to motd
      sudo mv /tmp/motd.backup /etc/motd
      # delete backup
      sudo rm /tmp/motd.backup
      # delete tmp motd.dins
      sudo rm /tmp/motd.dins
      ;;
  esac
}
# --- __set_state()
__set_state() {
  local STATE="$1"
  NEXT_STATE="$2"
  echo "${STATE}" > "$STATE_FILE"
  __reboot_triggered
}
# --- __clear_state()
__clear_state() {
  sudo rm "$STATE_FILE"
}
# --- __get_advertise_addr()
__get_advertise_addr() {
  # Try Ethernet first
  ETH_IP=$(ip -4 addr show eth0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
  if [[ -n "$ETH_IP" ]]; then
    __log "[NETWORK] Ethernet connected. Using $ETH_IP (eth0)"
    echo "$ETH_IP"
    return
  fi

  # Then Wi-Fi
  WLAN_IP=$(ip -4 addr show wlan0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
  if [[ -n "$WLAN_IP" ]]; then
    __log "[NETWORK] Using Wi-Fi IP $WLAN_IP (wlan0)"
    echo "$WLAN_IP"
    return
  fi

  # Finally fallback to hostname -I
  HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -n "$HOST_IP" ]]; then
    __log "[NETWORK] Falling back to hostname IP $HOST_IP"
    echo "$HOST_IP"
    return
  fi

  # If nothing found, stop script safely
  __log "[ERROR] No network IP found! Aborting Swarm init."
  echo ""
  return 1
}
# --- __expand_placeholders()
__expand_placeholders() {
  local input="$1"
  local output="$input"
  # Find all placeholders in the form {$NAME%}
  local matches
  matches=$(grep -o '\{\$[A-Za-z0-9_]*%\}' <<< "$input" || true)
  for match in $matches; do
    local varname="${match#\{\$}"
    varname="${varname%\%}}"
    local value
    value="$(eval echo "\$$varname")"
    output="${output//$match/$value}"
  done
  echo "$output"
}
# --- __set_placeholder()
__set_placeholder() {
  local VARNAME="$1"
  local PATHNAME="$2"

  # Ensure both args are provided
  #if [[ -z "$VARNAME" || -z "$PATHNAME" ]]; then
  #  echo "[ERROR] __set_placeholder requires 2 arguments: name and value" >&2
  #  return 1
  #fi

  # Export a real shell variable dynamically
  eval "export ${VARNAME}=\"${PATHNAME}\""
  log "[PLACEHOLDER] Registered: \${$VARNAME} → $PATHNAME"
}
# --- __reboot_triggered()
__reboot_triggered() {
  if [ -f /var/run/reboot-required ]; then
    __log "[REBOOT] Preparing to reboot now..."
    __boot_msg boot
    sync
    sudo reboot
  fi
}
# ==============================
# --- starting
start_install() {
  local LOGSTAMP=$(date -u +"%Y%m%d_%H%M%SZ")
  echo "[DINS] Installation started\n------------------------------------------------------------"
  # Save a persistent copy of this script if it doesn't already exist
#  if [ ! -f "$SCRIPT_FILE" ]; then
    echo "[DINS] Saving installer to $SCRIPT_FILE ..."
    curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_FILE"
    sudo chmod +x "$SCRIPT_FILE"
#  fi
  # start log file
  __log "---\n--- started installation $LOGSTAMP\n---" "open"
  # init login messenger
  __boot_msg init
  __set_state "run_initialize_ini" "[--] parse initialize.ini from repo"
}
# --- step 1
run_initialize_ini() {
  local INIT_FILE_URL="$BOOTSTRAP_URL/initialize.ini"
  local INIT_TMP="/tmp/etc/dins/setup/initialize.ini"
  local MODE=""
  local SUBMODE=""
  __log "[INIT] Fetching initialize.ini from $INIT_FILE_URL ..."
  __exec_mkdir "/tmp/etc/dins/setup"
  curl -fsSL "$INIT_FILE_URL" -o "$INIT_TMP"
  if [ ! -s "$INIT_TMP" ]; then
    __log "[ERROR] Failed to fetch initialize.ini from $INIT_FILE_URL"
    return 1
  fi
  __log "[INIT] Reading $INIT_TMP ..."
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(echo "$line" | xargs)
    [[ -z "$line" || "$line" =~ ^#|^; ]] && continue
    # Section header
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      MODE=$(echo "${BASH_REMATCH[1]}" | cut -d':' -f1)
      SUBMODE=$(echo "${BASH_REMATCH[1]}" | cut -d':' -f2)
      __log "[INIT] Mode: $MODE ($SUBMODE)"
      continue
    fi
    # Split key=value
    local key=$(echo "$line" | cut -d'=' -f1 | xargs)
    local value=$(echo "$line" | cut -d'=' -f2- | xargs)
    [[ -z "$key" || -z "$value" ]] && continue
    # Expand placeholders & register them
    __set_placeholder "$key" "$value"
    local expanded_value
    expanded_value="$(__expand_placeholders "$value")"
    # Execute handler if it exists
    local fn="__exec_${MODE}"
    if declare -f "$fn" >/dev/null 2>&1; then
      "$fn" "$key" "$expanded_value"
    else
      __log "[WARN] Unknown mode handler: $MODE ($key=$value)"
    fi
  done < "$INIT_TMP"
  __log "[INIT] initialize.ini processing completed."
  __boot_msg post "[OK] parsed initialize.ini from repo"
  __set_state "setup_dins_command" "[--] set up dins command : dinser"
}
# --- step 2
setup_dins_command() {
  # === DINS Installation Paths ===
  DINS_HELPER="$USR_PATH/local/bin/dins/dinser"   # main executable command
  DINS_CONFIG="$OPT_PAT/config"
# --- Ensure base directories exist ---
  __exec_mkdir "path" "$DINS_CONFIG"
  sudo chmod -R 755 "$BIN_PATH"
  # --- Create the global 'dins' command ---
  {
    echo '#!/bin/bash'
    echo '# Global DINS command dispatcher'
    echo ''
    echo 'if [[ -z "$1" ]]; then'
    echo '  echo "Usage: dins <command> [args]"'
    echo '  echo "Example: dins setup, dins logs, dins config"'
    echo '  echo "Available commands:"'
    echo '  ls /usr/local/lib/dins | sed "s/.sh//g" | xargs -n1 echo "  -"'
    echo '  exit 0'
    echo 'fi'
    echo ''
    echo 'CMD="/usr/local/lib/dins/${1}.sh"'
    echo 'if [[ -x "$CMD" ]]; then'
    echo '  shift'
    echo '  exec "$CMD" "$@"'
    echo 'else'
    echo '  echo "Unknown DINS command: $1" >&2'
    echo '  echo "Available commands:" >&2'
    echo '  ls /usr/local/lib/dins | sed "s/.sh//g" | xargs -n1 echo "  -" >&2'
    echo '  exit 1'
    echo 'fi'
  } | sudo tee "$DINS_HELPER" >/dev/null
  sudo chmod +x "$DINS_HELPER"
  sudo cp "$BOOTSTRAP_PATH/$(basename "$0")" "$BIN_PATH/setup.sh"
  sudo chmod +x "$BIN_PATH/setup.sh"
  # --- release (only temporary command)
  DINS_RELEASE="$BIN_PATH/release.sh"
    {
    echo '#!/bin/bash'
    echo ''
    echo '# remove state file'
    echo 'sudo rm $SCRIPT_PATH/state'
    echo '# remove srcipt - regular /home/pi/install.sh'
    echo 'sudo rm $SCRIPT_PATH/install.sh'
    echo '# remove script file from bootstrap path'
    echo 'sudo rm $BOOTSTRAP_PATH/install.sh'
    echo '# remove setup.sh from dinser command'
    echo 'sudo rm $DINS_LIB/setup.sh'
    echo '# stop and remove dins-setup service from docker'
    echo 'sudo docker stop dins-setup 2>/dev/null || true'
    echo 'sudo docker rm dins-setup 2>/dev/null || true'
    echo ''
    echo ''
  } | sudo tee "$DINS_RELEASE" >/dev/null
  sudo chmod +x "$DINS_RELEASE"
  __set_state "up_raspi" "[--] update and upgrade raspberry pi os packages"
}
# --- step 3
up_raspi() {
  # update raspberry pi os
  sudo apt-get update -qq -y > /dev/null
  # upgrade raspberry pi os
  sudo apt-get upgrade -qq -y > /dev/null
  __log "[APT] System updated and upgraded."
  __boot_msg post "[OK] update and upgrade Raspberry Pi OS"
  __set_state "prerequisites" "[--] install prerequisites"
}
# --- step 4
prerequisites() {
  # install apt-transport-https ca-certificates
  if apt-cache show software-properties-common > /dev/null 2>&1; then
    sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common > /dev/null
  else
    sudo apt-get install -qq -y apt-transport-https ca-certificates curl gnupg lsb-release > /dev/null
  fi
  __log "[APT] Prerequisites installed."
  __boot_msg post "[OK] Prerequisites installed"
  __set_state "inst_docker" "[--] Installing Docker"
}
# --- step 5
inst_docker() {
  # download docker official gpg key
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  # get docker download
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  # update packages before installation
  sudo apt-get update -qq -y > /dev/null
  # install docker
  sudo apt-get install -qq -y docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null
  __log "[DOCKER] Docker installed successfully."
 __boot_msg post "[OK] Docker installed"
  __set_state "enable_docker" "[--] Enabling Docker"
}
# --- step 6
enable_docker() {
  # enable docker
  sudo systemctl enable docker > /dev/null
  # add docker user
  sudo usermod -aG docker "$USER"
  __log "[DOCKER] Docker enabled and user added to group."
  __boot_msg post "[OK] Docker enabled"
  __set_state "init_docker_swarm" "[--] Initializing Docker Swarm"
}
# --- step 7
init_docker_swarm() {
  # init docker swarm
  if ! docker info 2>/dev/null | grep -q 'Swarm: active'; then
    IP_ADDR=$(__get_advertise_addr | tail -n1 | xargs)
    if [[ -z "$IP_ADDR" ]]; then
      __log "[ERROR] No valid IP found for Docker Swarm. Skipping initialization."
      __boot_msg post "[XX] No valid IP found for Docker Swarm. Skipping initialization"
      # reset next-state 
      echo "init_docker_swarm" > ./state
      return 1
    fi
    __log "[SWARM] Initializing Docker Swarm on $IP_ADDR ..."
    sudo docker swarm init --advertise-addr "$IP_ADDR" || true
  else
    __log "[SWARM] Docker Swarm already active."
  fi
  __boot_msg post "[OK] Docker Swarm initialized"
  __set_state "pull_setup_image" "[--] Pull Docker Setup Image"
}
# --- step 8
pull_setup_image() {
  local LOCAL_IMAGE="dins-setup:local"
  local REMOTE_IMAGE="ghcr.io/conceptixx/dins-setup:latest"
  # Prefer local build if available
  if docker image inspect "$LOCAL_IMAGE" > /dev/null 2>&1; then
    IMAGE_NAME="$LOCAL_IMAGE"
    __log "[IMAGE] Using local setup image: $LOCAL_IMAGE"
  # get current repo image if necessary
  else
    IMAGE_NAME="$REMOTE_IMAGE"
    if ! sudo docker image inspect "$REMOTE_IMAGE" > /dev/null 2>&1; then
      __log "[IMAGE] Pulling setup image: $REMOTE_IMAGE"
      sudo docker pull --disable-content-trust=true "$REMOTE_IMAGE"
      __log "[IMAGE] Setup image pulled successfully."
    else
      __log "[IMAGE] Setup image already present locally."
    fi
  fi
  __boot_msg post "[OK] Docker Setup Image ready ($IMAGE_NAME)"
  __set_state "run_setup_image" "[--] Running Setup Image"
}
# --- step 9
run_setup_image() {
  IMAGE_NAME="ghcr.io/conceptixx/dins-setup:latest"
  # Remove any existing container before starting
  sudo docker rm -f dins-setup >/dev/null 2>&1 || true
  # Common Docker run 
  local BASE_OPTS=(
    --name dins-setup
    --mount type=bind,src=/srv/docker/services,dst=/mnt/dins
  )
  # Create the helper script for console re-attachment
  local HELPER_PATH="/usr/local/bin/DINS-Setup"
  __log "[HELPER] Creating helper tool at $HELPER_PATH"
  {
    echo '#!/bin/bash'
    echo 'if sudo docker ps --format "{{.Names}}" | grep -q "^dins-setup$"; then'
    echo '  echo "[DINS] Attaching to running setup container (Ctrl+C to exit)..."'
    echo '  sudo docker attach dins-setup'
    echo 'else'
    echo '  echo "[DINS] No running setup container found. Starting one now..."'
    echo '  sudo /home/pi/install.sh --C --E'
    echo 'fi'
  } | sudo tee "$HELPER_PATH" >/dev/null
  sudo chmod +x "$HELPER_PATH"
  __log "[HELPER] DINS-Setup command available globally."
  __set_state "run_install_completed" "[--] complete basic installation"
}
# --- step 10
run_install_completed() {
  __boot_msg close
  __clear_state
}
# --- main()
main() {
# Parse parameters
  local parse_opt="$1"
  # Check if simulation flag was provided
  if [[ "$parse_opt" =~ ^(-s|-S|--simulate)$ ]]; then
    sudo touch "$SCRIPT_DIR/SIMULATE"
  fi
  # Check if simulation flag file exists
  if [[ -f "$SCRIPT_DIR/SIMULATE" ]]; then
    IS_SIMULATED="true"
  fi

  while true; do
    case "$(xargs < ./state 2>/dev/null)" in
      # --- step 1
      run_initialize_ini) run_initialize_ini ;;
      # --- step 2
      setup_dins_command) setup_dins_command ;;
      # --- step 3
      up_raspi) up_raspi ;;
      # --- step 4
      prerequisites) prerequisites ;;
      # --- step 5
      inst_docker) inst_docker ;;
      # --- step 6
      enable_docker) enable_docker ;;
      # --- step 7
      init_docker_swarm) init_docker_swarm ;;
      # --- step 8
      pull_setup_image) pull_setup_image ;;
      # --- step 9
      run_setup_image) run_setup_image ;;
      # --- step 10
      run_install_completed) run_install_completed; break ;;
      # --- starting
      *) start_install ;;
    esac  done
}
# start main function
main "$@"
# end of file