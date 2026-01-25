#!/bin/bash
# KDC Connectivity Test Script
# Run this on your Mac to diagnose Kerberos connectivity issues

echo "=========================================="
echo "KDC Connectivity Diagnostic"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

KDC_HOST="kdc.cube.k8s"
KDC_IP="10.10.10.110"
KDC_PORT=88

echo "Step 1: Check /etc/hosts"
echo "----------------------------------------"
if grep -q "$KDC_HOST" /etc/hosts 2>/dev/null; then
    echo -e "${GREEN}✓${NC} $KDC_HOST found in /etc/hosts"
    grep "$KDC_HOST" /etc/hosts
else
    echo -e "${RED}✗${NC} $KDC_HOST NOT found in /etc/hosts"
    echo ""
    echo "Fix: Add to /etc/hosts:"
    echo "  sudo sh -c 'echo \"$KDC_IP $KDC_HOST file-server.cube.k8s file-server kdc\" >> /etc/hosts'"
fi

echo ""
echo "Step 2: Check DNS Resolution"
echo "----------------------------------------"
if host "$KDC_HOST" &>/dev/null || nslookup "$KDC_HOST" &>/dev/null; then
    echo -e "${GREEN}✓${NC} $KDC_HOST resolves"
    host "$KDC_HOST" 2>/dev/null || nslookup "$KDC_HOST" 2>/dev/null | grep -A 1 "Name:"
else
    echo -e "${RED}✗${NC} $KDC_HOST does not resolve"
    echo "Trying IP address..."
    if ping -c 1 -W 2 "$KDC_IP" &>/dev/null; then
        echo -e "${YELLOW}!${NC} IP $KDC_IP is reachable but hostname doesn't resolve"
        echo "Add to /etc/hosts (see Step 1)"
    else
        echo -e "${RED}✗${NC} IP $KDC_IP is not reachable"
        echo "Check network connectivity"
    fi
fi

echo ""
echo "Step 3: Check Network Connectivity"
echo "----------------------------------------"
if ping -c 1 -W 2 "$KDC_HOST" &>/dev/null; then
    echo -e "${GREEN}✓${NC} Can ping $KDC_HOST"
else
    echo -e "${RED}✗${NC} Cannot ping $KDC_HOST"
    if ping -c 1 -W 2 "$KDC_IP" &>/dev/null; then
        echo -e "${YELLOW}!${NC} Can ping IP $KDC_IP but not hostname"
        echo "This is a DNS/hosts file issue"
    else
        echo -e "${RED}✗${NC} Cannot ping IP $KDC_IP either"
        echo "Network connectivity problem"
    fi
fi

echo ""
echo "Step 4: Check KDC Port (88)"
echo "----------------------------------------"
if nc -z -w 2 "$KDC_HOST" "$KDC_PORT" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} KDC port $KDC_PORT is open on $KDC_HOST"
elif nc -z -w 2 "$KDC_IP" "$KDC_PORT" 2>/dev/null; then
    echo -e "${YELLOW}!${NC} KDC port $KDC_PORT is open on IP $KDC_IP"
    echo "But hostname $KDC_HOST doesn't work - DNS/hosts issue"
else
    echo -e "${RED}✗${NC} Cannot connect to KDC port $KDC_PORT"
    echo "KDC service may not be running or firewall blocking"
fi

echo ""
echo "Step 5: Check /etc/krb5.conf"
echo "----------------------------------------"
if [ -f /etc/krb5.conf ]; then
    echo -e "${GREEN}✓${NC} /etc/krb5.conf exists"
    echo ""
    echo "Realm configuration:"
    grep -A 3 "CUBE.K8S" /etc/krb5.conf 2>/dev/null || echo -e "${RED}✗${NC} CUBE.K8S realm not found"
else
    echo -e "${RED}✗${NC} /etc/krb5.conf does not exist"
    echo ""
    echo "Create it with:"
    echo "  sudo nano /etc/krb5.conf"
fi

echo ""
echo "Step 6: Check Time Sync"
echo "----------------------------------------"
LOCAL_TIME=$(date +%s)
echo "Local time: $(date)"
echo ""
echo "Time sync is critical for Kerberos (must be within 5 minutes)"
echo "To sync: sudo sntp -sS time.apple.com"

echo ""
echo "=========================================="
echo "Diagnostic Summary"
echo "=========================================="
echo ""
echo "Common fixes:"
echo ""
echo "1. Add to /etc/hosts:"
echo "   sudo sh -c 'echo \"10.10.10.110 kdc.cube.k8s file-server.cube.k8s file-server kdc\" >> /etc/hosts'"
echo ""
echo "2. Create /etc/krb5.conf:"
echo "   sudo tee /etc/krb5.conf << 'EOF'"
echo "[libdefaults]"
echo "    default_realm = CUBE.K8S"
echo "    dns_lookup_realm = false"
echo "    dns_lookup_kdc = false"
echo ""
echo "[realms]"
echo "    CUBE.K8S = {"
echo "        kdc = kdc.cube.k8s"
echo "        admin_server = kdc.cube.k8s"
echo "    }"
echo ""
echo "[domain_realm]"
echo "    .cube.k8s = CUBE.K8S"
echo "    cube.k8s = CUBE.K8S"
echo "EOF"
echo ""
echo "3. Test connectivity:"
echo "   ping kdc.cube.k8s"
echo "   nc -zv kdc.cube.k8s 88"
echo ""
echo "4. Test kinit:"
echo "   kinit gustavo@CUBE.K8S"
