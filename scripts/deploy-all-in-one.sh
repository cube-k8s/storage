#!/bin/bash
# All-in-one deployment script for KDC + File Server on same host

set -e

echo "=========================================="
echo "All-in-One File Server Deployment"
echo "KDC + File Server on Same Host"
echo "=========================================="
echo ""

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: ansible-playbook not found. Please install Ansible first."
    exit 1
fi

# Check if inventory exists
if [ ! -f "inventory/hosts.yml" ]; then
    echo "Error: inventory/hosts.yml not found."
    exit 1
fi

# Check if variables exist
if [ ! -f "group_vars/kdc.yml" ]; then
    echo "Error: group_vars/kdc.yml not found."
    exit 1
fi

if [ ! -f "group_vars/fileservers.yml" ]; then
    echo "Error: group_vars/fileservers.yml not found."
    exit 1
fi

# Check if KDC variables are encrypted
VAULT_ARGS=""
if grep -q "ANSIBLE_VAULT" group_vars/kdc.yml; then
    echo "✓ Detected encrypted KDC variables file."
    VAULT_ARGS="--ask-vault-pass"
else
    echo "⚠ Warning: group_vars/kdc.yml is not encrypted!"
    echo "  Consider encrypting it with: ansible-vault encrypt group_vars/kdc.yml"
    echo ""
fi

# Display deployment plan
echo "Deployment Plan:"
echo "----------------"
echo "1. Deploy Kerberos KDC"
echo "2. Create service principals (nfs, cifs)"
echo "3. Export keytabs"
echo "4. Deploy file server (Samba, NFS)"
echo "5. Configure Kerberos authentication"
echo ""
echo "Target host: $(grep ansible_host inventory/hosts.yml | head -1 | awk '{print $2}')"
echo ""

# Ask for confirmation
read -p "Continue with deployment? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Run the playbook
echo ""
echo "Starting deployment..."
echo ""

ansible-playbook playbooks/all-in-one.yml $VAULT_ARGS

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Your server is now running:"
echo "  ✓ Kerberos KDC"
echo "  ✓ Samba file server"
echo "  ✓ NFS file server (if enabled)"
echo ""
echo "Next steps:"
echo "1. Create users: ssh to server and run 'kadmin.local'"
echo "2. Configure clients: see docs/user-management-and-mounting.md"
echo "3. Test mounting: kinit user@REALM && mount share"
echo ""
echo "For detailed instructions, see:"
echo "  - docs/kdc-setup-guide.md"
echo "  - docs/user-management-and-mounting.md"
echo ""
