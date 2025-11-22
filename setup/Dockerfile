# ===============================
# DINS Setup Container
# ===============================
FROM python:3.11-slim

LABEL maintainer="conceptixx"
LABEL description="DINS Setup and Node Configuration Service"

RUN apt-get update -qq && apt-get install -yqq bash curl iproute2 net-tools && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/dins/setup
COPY setup_manager.py ./setup_manager.py

EXPOSE 8080
ENTRYPOINT ["python3", "setup_manager.py"]