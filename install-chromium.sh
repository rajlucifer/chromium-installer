#!/bin/bash
set -e

# Colors for output
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

function info() {
  echo -e "${YELLOW}[*] $1${RESET}"
}

function success() {
  echo -e "${GREEN}[+] $1${RESET}"
}

function error() {
  echo -e "${RED}[-] $1${RESET}"
}

info "🔧 Updating system packages..."
sudo apt update && sudo apt upgrade -y

info "🐳 Installing Docker..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

sudo apt-get install -y ca-certificates curl gnupg lsb-release ufw

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

info "🔐 Adding user to Docker group..."
sudo usermod -aG docker $USER
newgrp docker

# Validate docker access
if ! docker info >/dev/null 2>&1; then
  error "Docker command failed. Try: logout & login again or run 'newgrp docker'"
  exit 1
fi

# Ask for user input
echo ""
echo -e "${YELLOW}🔐 Setup Chromium Login${RESET}"
read -p "👤 Enter Chromium username: " CHROME_USER
read -p "🔑 Enter Chromium password (visible): " CHROME_PASS

info "📁 Creating Chromium configuration directory..."
CONFIG_DIR=~/chromium-config
mkdir -p "$CONFIG_DIR"
cd "$CONFIG_DIR"

TZ_VAL=$(realpath --relative-to /usr/share/zoneinfo /etc/localtime 2>/dev/null || echo "Etc/UTC")

# Remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -qw chromium; then
  info "📦 Removing existing Chromium container..."
  docker rm -f chromium || true
fi

# Create Docker Compose
cat <<EOF > docker-compose.yaml
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=$CHROME_USER
      - PASSWORD=$CHROME_PASS
      - PUID=1000
      - PGID=1000
      - TZ=$TZ_VAL
      - CHROME_CLI=about:blank
    volumes:
      - $CONFIG_DIR:/config
    ports:
      - "3011:3000"
    shm_size: "2gb"
    restart: unless-stopped
EOF

info "🚀 Launching Chromium container..."
docker compose up -d

info "🛡️ Configuring UFW firewall..."
sudo ufw allow 3011/tcp
if ! sudo ufw status | grep -q "Status: active"; then
  sudo ufw --force enable
fi

info "🌐 Access Info"
success "✅ Chromium is installed and running!"
echo -e "🌍 Open in browser: ${GREEN}http://<your-server-ip>:3011/${RESET}"
echo -e "👤 Username: ${GREEN}$CHROME_USER${RESET}"
echo -e "🔑 Password: ${GREEN}$CHROME_PASS${RESET}"
echo -e "⚠️  If prompted, click 'Advanced' > 'Proceed' to bypass the self-signed SSL warning."
echo -e "💡 Tip: Allow port 3011 in your cloud provider settings if needed."
echo -e "👍 Enjoy!"

