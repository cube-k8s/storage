#!/bin/bash
# Setup Linux NFS client for NFSv4 with Kerberos support
# This script configures a Debian/Ubuntu client to mount NFS shares

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Linux NFS Client Setup ===${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# Install required packages
echo -e "${YELLOW}Installing NFS client packages...${NC}"
apt-get update
apt-get install -y nfs-common krb5-user libnfsidmap2 nfs4-acl-tools

# Configure NFSv4 domain
echo -e "${YELLOW}Configuring NFSv4 domain...${NC}"
if [ ! -f /etc/idmapd.conf ]; then
    cat > /etc/idmapd.conf <<EOF
[General]
Domain = cube.k8s

[Mapping]
Nobody-User = nobody
Nobody-Group = nogroup
EOF
else
    # Update existing file
    sed -i 's/^#\?\s*Domain\s*=.*/Domain = cube.k8s/' /etc/idmapd.conf
    if ! grep -q "^Domain = " /etc/idmapd.conf; then
        sed -i '/^\[General\]/a Domain = cube.k8s' /etc/idmapd.conf
    fi
fi

# Enable GSS for Kerberos
echo -e "${YELLOW}Enabling Kerberos support...${NC}"
if [ ! -f /etc/default/nfs-common ]; then
    cat > /etc/default/nfs-common <<EOF
NEED_STATD=yes
NEED_IDMAPD=yes
NEED_GSSD=yes
EOF
else
    sed -i 's/^NEED_GSSD=.*/NEED_GSSD=yes/' /etc/default/nfs-common
    if ! grep -q "^NEED_GSSD=" /etc/default/nfs-common; then
        echo "NEED_GSSD=yes" >> /etc/default/nfs-common
    fi
    sed -i 's/^NEED_IDMAPD=.*/NEED_IDMAPD=yes/' /etc/default/nfs-common
    if ! grep -q "^NEED_IDMAPD=" /etc/default/nfs-common; then
        echo "NEED_IDMAPD=yes" >> /etc/default/nfs-common
    fi
fi

# Configure NFS versions
echo -e "${YELLOW}Configuring NFS versions...${NC}"
if [ ! -f /etc/nfs.conf ]; then
    cat > /etc/nfs.conf <<EOF
[nfsd]
 vers4 = y
 vers3 = y
 vers2 = n
EOF
else
    # Ensure NFSv4 is enabled
    if ! grep -q "^\[nfsd\]" /etc/nfs.conf; then
        echo "[nfsd]" >> /etc/nfs.conf
    fi
    sed -i '/^\[nfsd\]/a\ vers4 = y' /etc/nfs.conf
fi

# Restart services
echo -e "${YELLOW}Restarting NFS services...${NC}"
systemctl restart rpc-gssd || true
systemctl restart nfs-idmapd || systemctl restart nfs-idmap || true
systemctl restart nfs-client.target || true

# Enable services
systemctl enable rpc-gssd || true
systemctl enable nfs-idmapd || systemctl enable nfs-idmap || true

echo -e "${GREEN}=== NFS Client Configuration Complete ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure /etc/krb5.conf with your Kerberos realm"
echo "2. Obtain a Kerberos ticket: kinit user@REALM"
echo "3. Mount NFS share:"
echo "   sudo mount -t nfs -o sec=krb5,vers=4 server:/path /mnt/point"
echo ""
echo -e "${YELLOW}Check service status:${NC}"
systemctl status rpc-gssd --no-pager || true
echo ""
systemctl status nfs-idmapd --no-pager || systemctl status nfs-idmap --no-pager || true
