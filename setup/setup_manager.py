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

def show_mode_summary():
    simulate = os.getenv("SIMULATE", "false").lower() == "true"
    webui = os.getenv("ENABLE_WEBUI", "false").lower() == "true"
    console = os.getenv("ENABLE_CONSOLE", "false").lower() == "true"
    execute = os.getenv("AUTO_EXECUTE", "false").lower() == "true"

    print("")  # empty line for spacing
    print("THIS MESSAGE COMES FROM INSIDE THE DINS-SETUP-SERVICE/CONTAINER", flush=True)
    if console: print("--C GIVEN", flush=True)
    if execute: print("--E GIVEN", flush=True)
    if simulate: print("--S GIVEN", flush=True)
    if webui: print("--W GIVEN", flush=True)
    print("THIS SCRIPT INSIDE NOW IS IDLE", flush=True)
    print("")

if __name__ == "__main__":
    log("Setup container started.")
    ensure_dirs()
    show_mode_summary()

    # Keep container alive (simulate service)
    while True:
        time.sleep(60)