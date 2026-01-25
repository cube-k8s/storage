#!/bin/bash
# Client Kerberos Configuration Setup Script
# This script configures a client machine to authenticate to the CUBE.K8S realm

set -e

echo "=========================================="
echo "Client Kerberos Configuration Setup"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
KDC_HOST="file-server.cube.k8s"
KDC_IP="10.10.10.110"
REALM="CUBE.K8S"
DOMAIN="cube.k8s"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

echo "Step 1: Check Kerberos client installation"
echo "----------------------------------------"

if command -v kinit &> /dev/null; then
    echo -e "${GREEN}✓${NC} Kerberos client is installed"
else
    echo -e "${YELLOW}!${NC} Kerberos client not found"
    echo "Installing krb5-user..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y krb5-user
    elif command -v yum &> /dev/null; then
        yum install -y krb5-workstation
    else
        echo -e "${RED}✗${NC} Cannot install Kerberos client automatically"
        echo "Please install manually and re-run this script"
        exit 1
    fi
fi

echo ""
echo "Step 2: Configure /etc/hosts"
echo "----------------------------------------"

if grep -q "$KDC_HOST" /etc/hosts; then
    echo -e "${GREEN}✓${NC} $KDC_HOST already in /etc/hosts"
else
    echo "Adding $KDC_HOST to /etc/hosts..."
    echo "$KDC_IP $KDC_HOST file-server" >> /etc/hosts
    echo -e "${GREEN}✓${NC} Added $KDC_HOST to /etc/hosts"
fi

echo ""
echo "Step 3: Test connectivity to KDC"
echo "----------------------------------------"

if ping -c 1 -W 2 "$KDC_HOST" &> /dev/null; then
    echo -e "${GREEN}✓${NC} Can reach $KDC_HOST"
else
    echo -e "${RED}✗${NC} Cannot reach $KDC_HOST"
    echo "Please check network connectivity and try again"
    exit 1
fi

echo ""
echo "Step 4: Configure /etc/krb5.conf"
echo "----------------------------------------"

# Backup existing config
if [ -f /etc/krb5.conf ]; then
    cp /etc/krb5.conf /etc/krb5.conf.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${YELLOW}!${NC} Backed up existing /etc/krb5.conf"
fi

# Create new config
cat > /etc/krb5.conf << EOF
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false

[realms]
    $REALM = {
        kdc = $KDC_HOST
        admin_server = $KDC_HOST
    }

[domain_realm]
    .$DOMAIN = $REALM
    $DOMAIN = $REALM
EOF

echo -e "${GREEN}✓${NC} Created /etc/krb5.conf"

echo ""
echo "Step 5: Test Kerberos authentication"
echo "----------------------------------------"

echo "Testing with gustavo@$REALM..."
echo "Password: JpMMf@Gm0"
echo ""

if echo "JpMMf@Gm0" | kinit gustavo@$REALM 2>&1; then
    echo ""
    echo -e "${GREEN}✓${NC} Authentication successful!"
    echo ""
    echo "Ticket information:"
    klist
    echo ""
    kdestroy
    echo -e "${GREEN}✓${NC} Test ticket destroyed"
else
    echo ""
    echo -e "${RED}✗${NC} Authentication failed"
    echo "Please check KDC is running and principals are created"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Client Configuration Complete!${NC}"
echo "=========================================="
echo ""
echo "You can now authenticate with:"
echo "  kinit gustavo@$REALM"
echo "  kinit miria@$REALM"
echo ""
echo "To view your tickets:"
echo "  klist"
echo ""
echo "To destroy tickets:"
echo "  kdestroy"
echo ""
echo "Next steps:"
echo "  - Mount SMB shares: see docs/user-management-and-mounting.md"
echo "  - Mount NFS shares: see docs/user-management-and-mounting.md"
