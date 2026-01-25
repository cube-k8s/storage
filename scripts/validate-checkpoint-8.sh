#!/bin/bash
# Checkpoint 8 Validation Script
# This script validates file services (Samba and NFS) after deployment
# Run this on the Ansible controller after deploying to a test system

set -e

echo "=========================================="
echo "Checkpoint 8: File Services Validation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INVENTORY="inventory/hosts.yml"
PLAYBOOK="playbooks/all-in-one.yml"
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

echo "Step 1: Run Complete Playbook on Test System"
echo "----------------------------------------"

print_info "Running complete playbook (this may take several minutes)..."
if ansible-playbook "$PLAYBOOK" -i "$INVENTORY"; then
    print_status 0 "Playbook executed successfully"
else
    print_status 1 "Playbook execution failed"
    exit 1
fi

echo ""
echo "Step 2: Verify Samba Service"
echo "----------------------------------------"

# Check if smbd is running
print_info "Checking if smbd service is running..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active smbd" &> /dev/null; then
    print_status 0 "smbd service is running"
else
    print_status 1 "smbd service is not running"
fi

# Check if smbd is enabled
print_info "Checking if smbd service is enabled..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-enabled smbd" &> /dev/null; then
    print_status 0 "smbd service is enabled (will start on boot)"
else
    print_status 1 "smbd service is not enabled"
fi

# Check if Samba is listening on port 445
print_info "Checking if Samba is listening on port 445..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "ss -tlnp | grep -q ':445'" &> /dev/null; then
    print_status 0 "Samba is listening on port 445"
else
    print_status 1 "Samba is not listening on port 445"
fi

echo ""
echo "Step 3: Verify NFS Service"
echo "----------------------------------------"

# Check if nfs-server is running
print_info "Checking if nfs-server service is running..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active nfs-server" &> /dev/null; then
    print_status 0 "nfs-server service is running"
else
    print_status 1 "nfs-server service is not running"
fi

# Check if nfs-server is enabled
print_info "Checking if nfs-server service is enabled..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-enabled nfs-server" &> /dev/null; then
    print_status 0 "nfs-server service is enabled (will start on boot)"
else
    print_status 1 "nfs-server service is not enabled"
fi

# Check if NFS is listening on port 2049
print_info "Checking if NFS is listening on port 2049..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "ss -tlnp | grep -q ':2049'" &> /dev/null; then
    print_status 0 "NFS is listening on port 2049"
else
    print_status 1 "NFS is not listening on port 2049"
fi

echo ""
echo "Step 4: Verify Kerberos Integration"
echo "----------------------------------------"

# Check rpc-gssd for NFS Kerberos
print_info "Checking if rpc-gssd service is running..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active rpc-gssd" &> /dev/null; then
    print_status 0 "rpc-gssd service is running"
else
    print_status 1 "rpc-gssd service is not running"
fi

# Check rpc-svcgssd for NFS Kerberos
print_info "Checking if rpc-svcgssd service is running..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-active rpc-svcgssd" &> /dev/null; then
    print_status 0 "rpc-svcgssd service is running"
else
    print_status 1 "rpc-svcgssd service is not running"
fi

# Check keytab exists
print_info "Checking if keytab file exists..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "test -f /etc/krb5.keytab" &> /dev/null; then
    print_status 0 "Keytab file exists at /etc/krb5.keytab"
else
    print_status 1 "Keytab file not found"
fi

echo ""
echo "Step 5: Verify Service Auto-Start Configuration"
echo "----------------------------------------"

print_info "Verifying services are configured to start automatically..."

# Check all critical services are enabled
SERVICES=("smbd" "nmbd" "nfs-server" "rpc-gssd" "rpc-svcgssd")
ALL_ENABLED=0

for service in "${SERVICES[@]}"; do
    if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl is-enabled $service" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $service is enabled"
    else
        echo -e "  ${RED}✗${NC} $service is not enabled"
        ALL_ENABLED=1
    fi
done

if [ $ALL_ENABLED -eq 0 ]; then
    print_status 0 "All services are configured to start automatically"
else
    print_status 1 "Some services are not configured for auto-start"
fi

echo ""
echo "Step 6: Display Service Status Summary"
echo "----------------------------------------"

print_info "Fetching detailed service status..."
echo ""
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl status smbd --no-pager -l" 2>/dev/null | grep -A 3 "Active:"
echo ""
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl status nfs-server --no-pager -l" 2>/dev/null | grep -A 3 "Active:"

echo ""
echo "Step 7: Display Listening Ports"
echo "----------------------------------------"

print_info "Showing all listening ports for file services..."
echo ""
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "ss -tlnp | grep -E ':(445|2049)'" 2>/dev/null || echo "No ports found"

echo ""
echo "Step 8: Verify Service Status Details"
echo "----------------------------------------"

print_info "Checking detailed service status..."
echo ""
echo "=== Samba Services ==="
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl status smbd --no-pager | head -10" 2>/dev/null
echo ""
echo "=== NFS Services ==="
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl status nfs-server --no-pager | head -10" 2>/dev/null
echo ""
echo "=== Kerberos GSS Services ==="
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "systemctl status rpc-gssd --no-pager | head -10" 2>/dev/null

echo ""
echo "=========================================="
echo "Checkpoint 8 Validation Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Complete playbook: Executed successfully"
echo "  - Samba (SMB): Running and listening on port 445"
echo "  - NFS: Running and listening on port 2049"
echo "  - Kerberos integration: rpc-gssd and rpc-svcgssd running"
echo "  - Auto-start: All services enabled for automatic startup"
echo ""
echo "✓ All checkpoint 8 validation tests passed!"
echo ""
echo "Next steps:"
echo "  1. Test SMB connection from a client"
echo "  2. Test NFS mount from a client"
echo "  3. Verify Kerberos authentication works"
echo "  4. Proceed to implement configuration validation and logging"
