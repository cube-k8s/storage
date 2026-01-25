#!/bin/bash
# Quick Checkpoint 8 Test Script
# This script validates file services without re-running the playbook
# Run this on the Ansible controller to verify current state

set -e

echo "=========================================="
echo "Checkpoint 8: Quick Validation Test"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INVENTORY="inventory/hosts.yml"
TARGET_HOST="fileservers"

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        return 1
    fi
}

# Function to print info
print_info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Track failures
FAILURES=0

echo "Test 1: Verify Samba Service"
echo "----------------------------------------"

# Check if smbd is running
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active smbd" &> /dev/null; then
    print_status 0 "smbd service is running"
else
    print_status 1 "smbd service is not running"
    FAILURES=$((FAILURES + 1))
fi

# Check if smbd is enabled
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-enabled smbd" &> /dev/null; then
    print_status 0 "smbd service is enabled (will start on boot)"
else
    print_status 1 "smbd service is not enabled"
    FAILURES=$((FAILURES + 1))
fi

# Check if Samba is listening on port 445
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "ss -tlnp | grep -q ':445'" &> /dev/null; then
    print_status 0 "Samba is listening on port 445"
else
    print_status 1 "Samba is not listening on port 445"
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "Test 2: Verify NFS Service"
echo "----------------------------------------"

# Check if nfs-server is running
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active nfs-server" &> /dev/null; then
    print_status 0 "nfs-server service is running"
else
    print_status 1 "nfs-server service is not running"
    FAILURES=$((FAILURES + 1))
fi

# Check if nfs-server is enabled
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-enabled nfs-server" &> /dev/null; then
    print_status 0 "nfs-server service is enabled (will start on boot)"
else
    print_status 1 "nfs-server service is not enabled"
    FAILURES=$((FAILURES + 1))
fi

# Check if NFS is listening on port 2049
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "ss -tlnp | grep -q ':2049'" &> /dev/null; then
    print_status 0 "NFS is listening on port 2049"
else
    print_status 1 "NFS is not listening on port 2049"
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "Test 3: Verify Kerberos Integration"
echo "----------------------------------------"

# Check rpc-gssd for NFS Kerberos
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active rpc-gssd" &> /dev/null; then
    print_status 0 "rpc-gssd service is running"
else
    print_status 1 "rpc-gssd service is not running"
    FAILURES=$((FAILURES + 1))
fi

# Check rpc-svcgssd for NFS Kerberos
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active rpc-svcgssd" &> /dev/null; then
    print_status 0 "rpc-svcgssd service is running"
else
    print_status 1 "rpc-svcgssd service is not running"
    FAILURES=$((FAILURES + 1))
fi

# Check keytab exists
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "test -f /etc/krb5.keytab" &> /dev/null; then
    print_status 0 "Keytab file exists at /etc/krb5.keytab"
else
    print_status 1 "Keytab file not found"
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "Test 4: Verify Service Auto-Start Configuration"
echo "----------------------------------------"

# Check all critical services are enabled
SERVICES=("smbd" "nmbd" "nfs-server" "rpc-gssd" "rpc-svcgssd")

for service in "${SERVICES[@]}"; do
    if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-enabled $service" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $service is enabled"
    else
        echo -e "  ${RED}✗${NC} $service is not enabled"
        FAILURES=$((FAILURES + 1))
    fi
done

echo ""
echo "=========================================="
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✓ All Tests Passed!${NC}"
    echo "=========================================="
    echo ""
    echo "Checkpoint 8 validation successful!"
    echo "All file services are running and configured correctly."
    exit 0
else
    echo -e "${RED}✗ $FAILURES Test(s) Failed${NC}"
    echo "=========================================="
    echo ""
    echo "Some validation checks failed. Please review the output above."
    exit 1
fi
