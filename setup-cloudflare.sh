#!/bin/bash

# 🟢 Color functions with timestamps
log() { echo -e "\e[32m[$(date '+%H:%M:%S')] $1\e[0m"; }
error() { echo -e "\e[31m[$(date '+%H:%M:%S')] ERROR: $1\e[0m"; }

# ✅ Ask for tunnel name and domain
read -p "Enter a name for your tunnel: " TUNNEL_NAME
read -p "Enter the hostname (e.g. sub.example.com): " HOSTNAME

# ✅ Step 1: Update packages
log "Updating system..."
sudo apt update -y && sudo apt upgrade -y || error "System update failed."

# ✅ Step 2: Detect architecture and install cloudflared
ARCH=$(uname -m)
CLOUDFLARED_URL=""

if [[ "$ARCH" == "x86_64" ]]; then
  CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
elif [[ "$ARCH" == "aarch64" ]]; then
  CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb"
else
  error "Unsupported architecture: $ARCH"
  exit 1
fi

log "Downloading cloudflared for $ARCH..."
wget -q $CLOUDFLARED_URL -O cloudflared.deb
sudo dpkg -i cloudflared.deb || { error "Cloudflared installation failed."; exit 1; }

# ✅ Step 3: Authenticate with Cloudflare
log "Authenticating with Cloudflare..."
cloudflared tunnel login || { error "Login failed."; exit 1; }

# ✅ Step 4: Create tunnel
log "Creating tunnel: $TUNNEL_NAME"
cloudflared tunnel create "$TUNNEL_NAME" || { error "Tunnel creation failed."; exit 1; }

# ✅ Step 5: Create config.yml
log "Creating tunnel config..."
mkdir -p ~/.cloudflared
cat <<EOF > ~/.cloudflared/config.yml
tunnel: $TUNNEL_NAME
credentials-file: /home/$USER/.cloudflared/$TUNNEL_NAME.json

ingress:
  - hostname: $HOSTNAME
    service: http://localhost:80
  - service: http_status:404
EOF

# ✅ Step 6: Create systemd service
log "Setting up systemd service..."
sudo cloudflared service install || error "Failed to create systemd service"

# ✅ Step 7: Enable and start service
log "Starting Cloudflare Tunnel as a service..."
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

log "✅ Tunnel $TUNNEL_NAME is now running and pointing to $HOSTNAME!"
