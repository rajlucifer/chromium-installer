#!/bin/bash

set -e

info() {
  echo -e "\033[1;34m[*] $1\033[0m"
}

success() {
  echo -e "\033[1;32m[+] $1\033[0m"
}

error() {
  echo -e "\033[1;31m[!] $1\033[0m"
}

# Prompt for username and password
read -p "Enter a username for Chromium login: " CHROMIUM_USER
read -s -p "Enter a password for Chromium login: " CHROMIUM_PASS
echo

# Store credentials file for HTTP basic auth
CREDENTIALS_FILE="$HOME/chromium-auth.htpasswd"
docker run --rm --entrypoint htpasswd httpd:2 -Bbn "$CHROMIUM_USER" "$CHROMIUM_PASS" > "$CREDENTIALS_FILE"

# Update system
info "Updating system packages..."
sudo apt update && sudo apt upgrade -y
success "System updated."

# Install Docker if not installed
if ! command -v docker &> /dev/null; then
  info "Installing Docker..."
  sudo apt install -y docker.io
  sudo systemctl enable docker
  sudo systemctl start docker
  success "Docker installed."
else
  success "Docker already installed."
fi

# Install Docker plugins
info "Installing Docker Compose & Buildx plugins..."
sudo apt install -y docker-compose-plugin docker-buildx-plugin
success "Plugins installed."

# Add current user to Docker group
info "🔐 Adding user to Docker group..."
sudo usermod -aG docker "$USER"
success "User added to Docker group. You must log out and back in for changes to apply."

# Enable UFW and allow port 3011
info "🛡️ Configuring UFW Firewall for port 3011..."
sudo apt install -y ufw
sudo ufw allow 3011/tcp
sudo ufw allow OpenSSH
sudo ufw --force enable
success "Firewall rule added for Chromium WebUI (port 3011)."

# Create Dockerfile and config
WORKDIR="$HOME/chromium-docker"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

info "🛠️ Creating Dockerfile and config..."

cat > Dockerfile <<EOF
FROM zenika/alpine-chrome:with-node

EXPOSE 3001

CMD ["--no-sandbox", "--disable-gpu", "--headless", "--remote-debugging-address=0.0.0.0", "--remote-debugging-port=3001"]
EOF

# Create a simple HTTP auth proxy using Caddy
cat > Caddyfile <<EOF
:3011
reverse_proxy localhost:3001
basicauth {
    $CHROMIUM_USER $(echo "$CHROMIUM_PASS" | openssl passwd -apr1 -stdin)
}
EOF

# Create docker-compose.yaml
cat > docker-compose.yaml <<EOF
version: '3.8'

services:
  chromium:
    build: .
    ports:
      - "3001:3001"
    restart: unless-stopped

  proxy:
    image: caddy:2
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
    ports:
      - "3011:3011"
    restart: unless-stopped
EOF

# Build and run
info "🚀 Building Docker containers..."
docker compose build

info "📦 Starting Chromium and proxy services..."
docker compose up -d

success "Chromium Web UI is running."

PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
echo
success "🔗 Access your Chromium at: http://${PUBLIC_IP}:3011/"
echo -e "\033[1;33mUsername:\033[0m $CHROMIUM_USER"
echo -e "\033[1;33mPassword:\033[0m (what you just set)"
echo
info "⚠️ Note: Reboot your terminal or re-login for Docker group permissions to apply."
