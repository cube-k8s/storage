#!/bin/bash
# Quick deployment script for Kerberos KDC

set -e

echo "=========================================="
echo "Kerberos KDC Deployment Script"
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
    echo "Please create it from inventory/kdc-example.yml"
    exit 1
fi

# Check if KDC variables exist
if [ ! -f "group_vars/kdc.yml" ]; then
    echo "Error: group_vars/kdc.yml not found."
    echo "This file should contain your KDC configuration."
    exit 1
fi

# Check if variables are encrypted
if grep -q "ANSIBLE_VAULT" group_vars/kdc.yml; then
    echo "Detected encrypted variables file."
    VAULT_ARGS="--ask-vault-pass"
else
    echo "Warning: group_vars/kdc.yml is not encrypted!"
    echo "Consider encrypting it with: ansible-vault encrypt group_vars/kdc.yml"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    VAULT_ARGS=""
fi

# Ask for confirmation
echo ""
echo "This will deploy a Kerberos KDC to the hosts in the 'kdc' group."
echo ""
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

ansible-playbook playbooks/kdc.yml $VAULT_ARGS

echo ""
echo "=========================================="
echo "Deployment complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. SSH to your KDC and test: kinit admin/admin@YOUR.REALM"
echo "2. Create service principals for your file server"
echo "3. Update group_vars/fileservers.yml with KDC information"
echo "4. Deploy your file server: ansible-playbook playbooks/site.yml"
echo ""
echo "For detailed instructions, see: docs/kdc-setup-guide.md"
