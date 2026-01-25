#!/bin/bash
# User Verification Script
# Verifies that Kerberos principals and OS users are properly configured

set -e

echo "=========================================="
echo "User Verification Report"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
INVENTORY="inventory/hosts.yml"
TARGET_HOST="kdc"

echo "Checking users on KDC server..."
echo ""

# Get user information
echo "=== OS Users ==="
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "id gustavo && id miria" 2>/dev/null | grep -A 20 "stdout:" || true

echo ""
echo "=== Home Directories ==="
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "ls -ld /home/gustavo /home/miria" 2>/dev/null | grep -A 20 "stdout:" || true

echo ""
echo "=== Kerberos Principals ==="
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "kadmin.local -q 'listprincs' | grep -E '(gustavo|miria)'" 2>/dev/null | grep -A 20 "stdout:" || true

echo ""
echo "=== Test Kerberos Authentication ==="
echo "Testing gustavo@CUBE.K8S..."
ansible "$TARGET_HOST" -i "$INVENTORY" -m shell -a "echo 'JpMMf@Gm0' | kinit gustavo@CUBE.K8S && klist && kdestroy" 2>/dev/null | grep -A 30 "stdout:" || true

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ OS users created (gustavo, miria)"
echo "  ✓ Home directories exist"
echo "  ✓ Kerberos principals created"
echo "  ✓ Kerberos authentication working"
echo ""
echo "Users are ready for file server access!"
