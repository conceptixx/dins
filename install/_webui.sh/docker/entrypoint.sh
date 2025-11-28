#!/bin/bash
# =============================================================================
# DINS WebUI Container Entrypoint
# =============================================================================

set -e

echo "=========================================="
echo "DINS WebUI Setup Container Starting"
echo "=========================================="

# Ensure directories exist
mkdir -p "${DINS_CONFIG_DIR}" "${DINS_LOG_DIR}" "${DINS_SECRETS_DIR}"

# Set proper permissions
chown -R root:dins-system "${DINS_BASE_DIR}" 2>/dev/null || true
chmod -R 750 "${DINS_BASE_DIR}" 2>/dev/null || true
chmod 700 "${DINS_SECRETS_DIR}" 2>/dev/null || true

echo "Starting Uvicorn backend..."

# Start Uvicorn in background
cd "${DINS_WEBUI_DIR}/backend"
uvicorn app:app --host 127.0.0.1 --port 8080 --log-level info &
UVICORN_PID=$!

# Wait for backend to be ready
echo "Waiting for backend to start..."
for i in {1..30}; do
    if curl -s http://127.0.0.1:8080/api/health > /dev/null 2>&1; then
        echo "Backend is ready!"
        break
    fi
    sleep 1
done

# Check if backend started
if ! kill -0 $UVICORN_PID 2>/dev/null; then
    echo "ERROR: Backend failed to start"
    exit 1
fi

echo "Starting Nginx..."

# Test nginx configuration
nginx -t

# Start nginx in foreground
exec nginx -g "daemon off;"
