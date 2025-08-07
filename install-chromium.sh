#!/bin/bash
set -e

# Colors
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
NC="\e[0m"

info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}
success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}
error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

info "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

info "🧹 Removing old Docker versions..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

info "📥 Installing required dependencies..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release

info "🔑 Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

info "➕ Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

info "🐳 Installing Docker Engine and plugins..."
sudo apt update && sudo apt install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

info "🔐 Adding user to Docker group..."
sudo usermod -aG docker $USER

info "🔃 Refreshing group (no reboot required)..."
newgrp docker <<EONG

info "📁 Creating Chromium Docker folder..."
mkdir -p ~/chromium && cd ~/chromium

info "📝 Writing Docker Compose file..."
cat <<EOF > docker-compose.yaml
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=youruser
      - PASSWORD=yourpass
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Kolkata
      - CHROME_CLI=about:blank
    volumes:
      - /root/chromium/config:/config
    ports:
      - "3011:3001"
    shm_size: "2gb"
    restart: unless-stopped
EOF

info "🚀 Starting Chromium container..."
docker compose up -d

info "🧱 Installing ufw and allowing port 3011..."
sudo apt install -y ufw
sudo ufw allow 3011
sudo ufw reload

PUBLIC_IP=\$(curl -s ifconfig.me)
success "✅ Chromium is running at: http://\$PUBLIC_IP:3011/"
EONG

