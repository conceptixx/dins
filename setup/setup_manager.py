#!/usr/bin/env python3
import os
import time

def log(msg):
    print(f"[DINS-SETUP] {msg}", flush=True)

def ensure_dirs():
    base = "/mnt/dins"
    subdirs = ["services", "images", "configs", "volumes"]
    for s in subdirs:
        path = os.path.join(base, s)
        os.makedirs(path, exist_ok=True)
        log(f"Ensured directory: {path}")

if __name__ == "__main__":
    log("Setup container started.")
    ensure_dirs()
    log("Setup completed. Container now idle.")
    while True:
        time.sleep(60)