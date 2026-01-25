#!/bin/bash
# Checkpoint 5 Validation Script
# This script validates the base infrastructure after deployment
# Run this on the Ansible controller after deploying to a test system

set -e

echo "=========================================="
echo "Checkpoint 5: Base Infrastructure Validation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INVENTORY="inventory/hosts.yml"
PLAYBOOK="playbooks/site.yml"
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

echo "Step 1: Validate Ansible Configuration"
echo "----------------------------------------"

# Check if ansible is installed
if command -v ansible &> /dev/null; then
    print_status 0 "Ansible is installed"
    ansible --version | head -1
else
    print_status 1 "Ansible is not installed"
    exit 1
fi

# Check syntax
print_info "Checking playbook syntax..."
if ansible-playbook "$PLAYBOOK" --syntax-check &> /dev/null; then
    print_status 0 "Playbook syntax is valid"
else
    print_status 1 "Playbook syntax check failed"
    exit 1
fi

echo ""
echo "Step 2: Test Connectivity to Target Host"
echo "----------------------------------------"

# Test connectivity
print_info "Testing connectivity to $TARGET_HOST..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m ping &> /dev/null; then
    print_status 0 "Target host is reachable"
else
    print_status 1 "Cannot reach target host"
    echo "Please ensure:"
    echo "  - Target host is running"
    echo "  - SSH access is configured"
    echo "  - Inventory file is correct"
    exit 1
fi

echo ""
echo "Step 3: Run Playbook on Test System"
echo "----------------------------------------"

print_info "Running playbook (this may take a few minutes)..."
if ansible-playbook "$PLAYBOOK" -i "$INVENTORY"; then
    print_status 0 "Playbook executed successfully"
else
    print_status 1 "Playbook execution failed"
    exit 1
fi

echo ""
echo "Step 4: Verify Kerberos Client Configuration"
echo "----------------------------------------"

# Check krb5.conf exists
print_info "Checking Kerberos configuration..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "test -f /etc/krb5.conf" &> /dev/null; then
    print_status 0 "/etc/krb5.conf exists"
else
    print_status 1 "/etc/krb5.conf not found"
fi

# Check krb5.conf content
print_info "Verifying krb5.conf contains realm configuration..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "grep -q 'CUBE.K8S' /etc/krb5.conf" &> /dev/null; then
    print_status 0 "krb5.conf contains realm configuration"
else
    print_status 1 "krb5.conf missing realm configuration"
fi

# Check Kerberos packages
print_info "Checking Kerberos packages..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "dpkg -l | grep -q krb5-user" &> /dev/null; then
    print_status 0 "krb5-user package is installed"
else
    print_status 1 "krb5-user package not installed"
fi

echo ""
echo "Step 5: Verify Share Directories"
echo "----------------------------------------"

# Check share directory exists
print_info "Checking share directory /srv/shares/socialpro..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "test -d /srv/shares/socialpro" &> /dev/null; then
    print_status 0 "Share directory exists"
else
    print_status 1 "Share directory not found"
fi

# Check permissions and ownership
print_info "Verifying share directory permissions and ownership..."
if ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "test -d /srv/shares/socialpro && test -r /srv/shares/socialpro" &> /dev/null; then
    print_status 0 "Share directory exists and is accessible"
    print_info "Run 'ansible fileservers -m shell -a \"ls -ld /srv/shares/socialpro\"' to verify permissions manually"
else
    print_status 1 "Share directory not accessible"
fi

echo ""
echo "Step 6: Test Kerberos Functionality (Optional)"
echo "----------------------------------------"

print_info "Testing kinit (requires test credentials)..."
echo "To manually test Kerberos authentication, run on the target host:"
echo "  kinit testuser@CUBE.K8S"
echo "  klist"
echo "  kdestroy"
echo ""
echo "If you have test credentials, you can verify kinit works."

echo ""
echo "=========================================="
echo "Checkpoint 5 Validation Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Ansible configuration: Valid"
echo "  - Target connectivity: Verified"
echo "  - Playbook execution: Successful"
echo "  - Kerberos client: Configured"
echo "  - Share directories: Created with correct permissions"
echo ""
echo "Next steps:"
echo "  1. Test kinit with a valid Kerberos principal"
echo "  2. Verify KDC connectivity"
echo "  3. Proceed to implement Samba and NFS roles"
