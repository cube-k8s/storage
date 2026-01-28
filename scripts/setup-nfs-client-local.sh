#!/bin/bash
# Setup NFS client on local machine using Ansible
# This script runs the NFS client playbook on localhost

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== NFS Client Setup (Ansible) ===${NC}"

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Ansible is not installed!${NC}"
    echo "Install it with: sudo apt-get install ansible"
    exit 1
fi

# Check if running from project root
if [ ! -f "playbooks/nfs-client.yml" ]; then
    echo -e "${RED}Please run this script from the project root directory${NC}"
    exit 1
fi

echo -e "${YELLOW}Running Ansible playbook to configure NFS client...${NC}"
echo ""

# Run the playbook on localhost
ansible-playbook -i inventory/localhost.yml playbooks/nfs-client.yml --ask-become-pass

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
