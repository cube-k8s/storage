#!/bin/bash
# Prepare NFS directories for applications
# This script creates necessary directories on the NFS server with proper permissions

set -e

SERVER="file-server.cube.k8s"
BASE_PATH="/srv/shares"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Preparing NFS Directories ===${NC}"
echo ""

# Function to create directory structure
create_dir_structure() {
    local share=$1
    local path=$2
    local perms=${3:-777}
    
    echo -e "${YELLOW}Creating: ${BASE_PATH}/${share}${path}${NC}"
    ssh root@${SERVER} "mkdir -p ${BASE_PATH}/${share}${path} && chmod ${perms} ${BASE_PATH}/${share}${path}"
}

# PhotoStructure directories
echo "Creating PhotoStructure directories..."
create_dir_structure "photos-lib" "/.photostructure/docker-config" "777"
create_dir_structure "photos-lib" "/.photostructure/logs" "777"
create_dir_structure "photos-lib" "/.photostructure/cache" "777"
create_dir_structure "photos-lib" "/.photostructure/tmp" "777"

# Verify
echo ""
echo -e "${GREEN}Verifying directories...${NC}"
ssh root@${SERVER} "ls -la ${BASE_PATH}/photos-lib/.photostructure/"

echo ""
echo -e "${GREEN}✓ Directories created successfully!${NC}"
echo ""
echo "You can now deploy your PhotoStructure pod."
