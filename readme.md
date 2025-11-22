



git add .
git commit -m "Initial commit from local directory"
git branch -M main
git push -u origin main

curl -s https://raw.githubusercontent.com/conceptixx/dins/main/install.sh | sudo bash

curl -fsSL https://raw.githubusercontent.com/conceptixx/dins/main/install.sh | sudo bash -s -- --simulate