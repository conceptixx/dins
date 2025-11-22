#!/bin/bash
# DINS Setup Deployment Script for macOS

set -e

PI_USER="pi"
PI_HOST="dins-master.local"
PI_PATH="/home/pi/dins-setup"

echo "[DINS] Creating remote setup directory..."
ssh ${PI_USER}@${PI_HOST} "mkdir -p ${PI_PATH}"

echo "[DINS] Copying setup files..."
scp -r ./setup/* ${PI_USER}@${PI_HOST}:${PI_PATH}/

echo "[DINS] Building Docker image on remote Raspberry Pi..."
ssh ${PI_USER}@${PI_HOST} "cd ${PI_PATH} && sudo docker-compose build"

echo "[DINS] Starting setup container on dins-master..."
ssh ${PI_USER}@${PI_HOST} "cd ${PI_PATH} && sudo docker-compose up -d"

echo "[DINS] Setup container deployed and running on dins-master."