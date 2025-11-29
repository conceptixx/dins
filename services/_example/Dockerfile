# Example Service Dockerfile
# ==========================
# Template Dockerfile for DINS services per PART 9

FROM python:3.11-slim

# Labels for DINS management
LABEL dins.managed="true"
LABEL dins.type="example"
LABEL maintainer="dins-system"

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy application code
# NOTE: In real services, copy from src/
COPY src/ /app/

# Install Python dependencies (if any)
# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose service port
EXPOSE 8080

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Default command
CMD ["python", "main.py"]
