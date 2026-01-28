#!/bin/bash
# Test NFS mount on worker nodes
# Usage: ./test-nfs-mount.sh <hostname>

set -e

HOST=${1:-k8s-worker-01}

echo "Testing NFS mount on $HOST..."
echo ""

# Test NFSv4 mount
echo "=== Testing NFSv4 mount ==="
ssh root@$HOST "mkdir -p /mnt/socialpro && mount -t nfs -o vers=4 file-server.cube.k8s:/srv/shares/socialpro /mnt/socialpro && df -h | grep socialpro && umount /mnt/socialpro && echo 'NFSv4 mount successful!'"

echo ""
echo "=== Testing NFSv4 with Kerberos ==="
ssh root@$HOST "mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/socialpro /mnt/socialpro && df -h | grep socialpro && umount /mnt/socialpro && echo 'NFSv4 with Kerberos mount successful!'"

echo ""
echo "All tests passed!"
