



git add .
git commit -m "Initial commit from local directory"
git branch -M main
git push -u origin main

curl -s https://raw.githubusercontent.com/conceptixx/dins/main/install.sh | sudo bash

curl -fsSL https://raw.githubusercontent.com/conceptixx/dins/main/install.sh | sudo bash -s -- --simulate

docker buildx build --platform linux/arm64 -t dins-setup:local ./setup

docker tag dins-setup:local ghcr.io/conceptixx/dins-setup:latest
docker push ghcr.io/conceptixx/dins-setup:latest