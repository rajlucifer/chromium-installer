#!/bin/bash
set -e

function info() {
  echo -e "\033[1;34m[*]\033[0m $1"
}

function success() {
  echo -e "\033[1;32m[✔]\033[0m $1"
}

function error() {
  echo -e "\033[1;31m[✘]\033[0m $1" >&2
}

# Ask for Chromium login credentials
read -p "Enter a username for Chromium login: " chromium_user
read -s  "Enter a password for Chromium login: " chromium_pass
echo ""

# Update and install dependencies
info "Updating system packages..."
sudo apt update -y
sudo apt install -y curl docker.io docker-compose ufw

# Add user to docker group
info "🔐 Adding user to Docker group..."
sudo usermod -aG docker $USER

success "User added to docker group. Please log out and log in again for permissions to apply."

# Set up UFW port
info "Opening firewall port 3011..."
sudo ufw allow 3011/tcp || true

# Create project directory
mkdir -p ~/chromium-server
cd ~/chromium-server

# Create Dockerfile & files
cat <<EOF > Dockerfile
FROM zenika/alpine-chrome:with-node

RUN npm install -g serve

WORKDIR /app
COPY . .

CMD echo "Username: \$CHROME_USER" && echo "Password: \$CHROME_PASS" && google-chrome-stable --no-sandbox --disable-dev-shm-usage
EOF

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3'
services:
  chromium:
    build: .
    ports:
      - "3011:3001"
    environment:
      - CHROME_USER=$chromium_user
      - CHROME_PASS=$chromium_pass
EOF

# Show message
success "Setup complete. Now run the following commands:"
echo ""
echo "👉 Logout and log back in or run: newgrp docker"
echo "👉 Then run:"
echo ""
echo "cd ~/chromium-server && docker compose up --build"
echo ""
echo "After that, open in browser: http://<your-vps-ip>:3011/"
