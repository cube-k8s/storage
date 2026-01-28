#!/bin/bash
# Mount NFS share on macOS with Kerberos authentication
# Usage: ./mount-nfs-macos.sh [share_name]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVER="file-server.cube.k8s"
REALM="CUBE.K8S"
USER="${USER:-gustavo}"

# Share definitions
declare -A SHARES
SHARES[socialpro]="/srv/shares/socialpro"
SHARES[photos]="/srv/shares/photos-vol"
SHARES[photoslib]="/srv/shares/photos-lib"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is for macOS only"
    exit 1
fi

# Get share name from argument or prompt
SHARE_NAME="${1}"
if [ -z "$SHARE_NAME" ]; then
    echo "Available shares:"
    for share in "${!SHARES[@]}"; do
        echo "  - $share (${SHARES[$share]})"
    done
    echo ""
    read -p "Enter share name: " SHARE_NAME
fi

# Validate share name
if [ -z "${SHARES[$SHARE_NAME]}" ]; then
    print_error "Unknown share: $SHARE_NAME"
    echo "Available shares: ${!SHARES[@]}"
    exit 1
fi

SHARE_PATH="${SHARES[$SHARE_NAME]}"
MOUNT_POINT="/Volumes/${SHARE_NAME^}"

print_info "Mounting $SHARE_NAME from $SERVER"
print_info "Remote path: $SHARE_PATH"
print_info "Mount point: $MOUNT_POINT"
echo ""

# Check if Kerberos is configured
if [ ! -f /etc/krb5.conf ]; then
    print_warning "Kerberos not configured. Please configure /etc/krb5.conf first."
    print_info "See docs/macos-nfs-kerberos-mount.md for instructions"
    exit 1
fi

# Check for Kerberos ticket
print_info "Checking Kerberos ticket..."
if ! klist -s 2>/dev/null; then
    print_warning "No valid Kerberos ticket found"
    print_info "Obtaining Kerberos ticket for ${USER}@${REALM}..."
    kinit "${USER}@${REALM}"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to obtain Kerberos ticket"
        exit 1
    fi
fi

# Display ticket info
print_info "Current Kerberos ticket:"
klist | head -5

echo ""

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    print_info "Creating mount point: $MOUNT_POINT"
    sudo mkdir -p "$MOUNT_POINT"
fi

# Check if already mounted
if mount | grep -q "$MOUNT_POINT"; then
    print_warning "Share already mounted at $MOUNT_POINT"
    read -p "Unmount and remount? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Unmounting..."
        sudo umount "$MOUNT_POINT"
    else
        print_info "Exiting"
        exit 0
    fi
fi

# Mount with Kerberos
print_info "Mounting with Kerberos authentication..."
if sudo mount -t nfs -o resvport,sec=krb5 "${SERVER}:${SHARE_PATH}" "$MOUNT_POINT"; then
    print_info "${GREEN}✓${NC} Successfully mounted!"
    echo ""
    print_info "Mount details:"
    mount | grep "$MOUNT_POINT"
    echo ""
    print_info "Testing access..."
    ls -la "$MOUNT_POINT" | head -5
    echo ""
    print_info "${GREEN}Share is ready to use at: $MOUNT_POINT${NC}"
else
    print_error "Failed to mount share"
    print_info "Troubleshooting tips:"
    echo "  1. Check Kerberos ticket: klist"
    echo "  2. Verify network: ping $SERVER"
    echo "  3. Check server exports: ssh root@$SERVER exportfs -v"
    echo "  4. See docs/macos-nfs-kerberos-mount.md for more help"
    exit 1
fi
