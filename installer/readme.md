curl -s https://raw.githubusercontent.com/conceptixx/dins/main/install.sh | sudo bash

git add install.sh
git commit -m "reworked reboot pause resume mechanic"
git pull --rebase origin main
git push origin main

ssh-keygen -t ed25519 -C "pi@raspberrypi"

systemctl status dins-wake.service

sudo rm install.sh

# Stop and disable the wake service
sudo systemctl stop dins-resume-install.service
sudo systemctl disable dins-resume-install

# Remove the systemd unit file
sudo rm -f /etc/systemd/system/dins-resume-install
sudo rm -f /etc/systemd/system/multi-user.target.wants/dins-resume-install

# Remove the helper script
sudo rm -f /usr/local/bin/resume.sh

# Reload systemd to apply changes
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Verify removal
sudo systemctl list-unit-files | grep dins