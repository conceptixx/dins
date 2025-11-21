#!/bin/bash
set -e

# === Raspberry Pi sudo password ===
PASSWORD="B04-Z2P-ane-AI"  # Replace with actual password

# === Configuration ===
REMOTE_USER="pi"
REMOTE_HOST="dins-client01"
REMOTE_HOME="/home/pi"
INSTALLER_SCRIPT_LOCAL="./dins-installer.sh"
INSTALLER_SCRIPT_REMOTE="$REMOTE_HOME/dins-installer.sh"
INSTALLER_IMAGE="ghcr.io/dins/installer:latest"

# === Send the installer script ===
echo "[DEPLOY] Sending dins-installer.sh..."
sshpass -p "$PASSWORD" scp "$INSTALLER_SCRIPT_LOCAL" "$REMOTE_USER@$REMOTE_HOST:$INSTALLER_SCRIPT_REMOTE"
sshpass -p "$PASSWORD" ssh -tt "$REMOTE_USER@$REMOTE_HOST" "chmod +x $INSTALLER_SCRIPT_REMOTE"

# === Run the installer remotely ===
echo "[DEPLOY] Executing dins-installer.sh on $REMOTE_HOST..."
sshpass -p "$PASSWORD" ssh -tt "$REMOTE_USER@$REMOTE_HOST" "bash $INSTALLER_SCRIPT_REMOTE"

echo "[DEPLOY] Done."
