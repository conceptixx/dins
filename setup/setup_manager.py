import os
import sys
import time

def log(msg):
    print(f"[DINS-SETUP] {msg}", flush=True)

def ensure_dirs():
    base = "/mnt/dins"
    subdirs = ["services", "images", "configs", "volumes"]
    for s in subdirs:
        os.makedirs(os.path.join(base, s), exist_ok=True)
        log(f"Ensured directory: {os.path.join(base, s)}")

def main():
    simulate = os.getenv("SIMULATE", "false").lower() == "true"
    enable_webui = os.getenv("ENABLE_WEBUI", "false").lower() == "true"
    enable_console = os.getenv("ENABLE_CONSOLE", "false").lower() == "true"
    auto_execute = os.getenv("AUTO_EXECUTE", "false").lower() == "true"

    log("Setup container started.")
    log(f"--S simulate={simulate}")
    log(f"--W webUI={enable_webui}")
    log(f"--C console={enable_console}")
    log(f"--E execute={auto_execute}")

    ensure_dirs()
    log("Setup completed. Container now idle (Ctrl+C to stop).")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        log("Container stopped by user.")

if __name__ == "__main__":
    main()