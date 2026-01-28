# Kubernetes NFS with Kerberos - Examples

This directory contains ready-to-use Kubernetes manifests for mounting NFS shares with Kerberos authentication.

## Prerequisites

✅ Worker nodes configured with:
- NFS client packages installed
- Kerberos client configured
- Keytabs deployed to `/etc/krb5.keytab`
- `rpc-gssd` service running

✅ NFS server configured with:
- NFSv4 enabled
- Kerberos authentication enabled
- Exports configured with `sec=krb5`

## Examples

### 1. Simple NFS Pod
**File:** `simple-nfs-pod.yaml`

Basic pod that mounts NFS and writes test data.

```bash
# Deploy
kubectl apply -f simple-nfs-pod.yaml

# Check status
kubectl get pod nfs-test-pod

# View logs
kubectl logs nfs-test-pod

# Exec into pod
kubectl exec -it nfs-test-pod -- sh

# Inside pod, check mount
df -h | grep nfs
ls -la /mnt/data
cat /mnt/data/test-log.txt

# Cleanup
kubectl delete -f simple-nfs-pod.yaml
```

### 2. PersistentVolume and PersistentVolumeClaim
**File:** `nfs-pv-pvc.yaml`

Creates a PV/PVC for reusable NFS storage.

```bash
# Deploy
kubectl apply -f nfs-pv-pvc.yaml

# Check PV and PVC
kubectl get pv
kubectl get pvc

# Check pod
kubectl get pod app-with-pvc

# Test
kubectl exec -it app-with-pvc -- sh
# Inside: ls -la /usr/share/nginx/html

# Cleanup
kubectl delete -f nfs-pv-pvc.yaml
```

### 3. Web Application Deployment
**File:** `web-app-deployment.yaml`

Complete web application with 3 replicas sharing NFS storage.

```bash
# Deploy
kubectl apply -f web-app-deployment.yaml

# Check deployment
kubectl get deployment web-app
kubectl get pods -l app=web

# Check PV/PVC
kubectl get pv web-content-pv
kubectl get pvc web-content-pvc

# Create test content
kubectl exec -it $(kubectl get pod -l app=web -o jsonpath='{.items[0].metadata.name}') -- sh
# Inside pod:
echo "<h1>Hello from NFS!</h1>" > /usr/share/nginx/html/index.html
exit

# Test from another pod (should see same content)
kubectl exec -it $(kubectl get pod -l app=web -o jsonpath='{.items[1].metadata.name}') -- cat /usr/share/nginx/html/index.html

# Access the service
kubectl get svc web-service
kubectl port-forward svc/web-service 8080:80
# Open browser: http://localhost:8080

# Cleanup
kubectl delete -f web-app-deployment.yaml
```

### 4. Multi-Container Pod with Shared Storage
**File:** `multi-container-shared-storage.yaml`

Demonstrates multiple containers sharing the same NFS volume.

```bash
# Deploy
kubectl apply -f multi-container-shared-storage.yaml

# Check pod
kubectl get pod multi-container-nfs

# View writer logs
kubectl logs multi-container-nfs -c writer

# View reader logs
kubectl logs multi-container-nfs -c reader

# View processor logs
kubectl logs multi-container-nfs -c processor

# Exec into any container
kubectl exec -it multi-container-nfs -c writer -- sh
# Inside: cat /mnt/shared/shared-log.txt

# Cleanup
kubectl delete -f multi-container-shared-storage.yaml
```

### 5. StatefulSet with NFS
**File:** `statefulset-nfs.yaml`

StatefulSet where each pod shares the same NFS storage.

```bash
# Deploy
kubectl apply -f statefulset-nfs.yaml

# Check statefulset
kubectl get statefulset stateful-app
kubectl get pods -l app=stateful-app

# Each pod creates its own file in shared storage
kubectl exec -it stateful-app-0 -- ls -la /usr/share/nginx/html/

# Cleanup
kubectl delete -f statefulset-nfs.yaml
```

## Verification

### Check NFS Mount in Pod

```bash
# Get pod name
POD_NAME=$(kubectl get pod -l app=nfs-test -o jsonpath='{.items[0].metadata.name}')

# Exec into pod
kubectl exec -it $POD_NAME -- sh

# Inside pod, check mount
df -h | grep nfs
mount | grep nfs
ls -la /mnt/data
```

### Check from Worker Node

```bash
# Find which node the pod is running on
kubectl get pod $POD_NAME -o wide

# SSH to that node
ssh root@<node-name>

# Check NFS mounts
mount | grep nfs

# Check Kerberos
klist -k /etc/krb5.keytab
systemctl status rpc-gssd

# Check NFS mount on host
ls -la /mnt/socialpro/
```

### Verify Kerberos Authentication

```bash
# On worker node
ssh root@k8s-worker-01

# Check rpc-gssd is using Kerberos
journalctl -u rpc-gssd -n 50

# Should see messages about using Kerberos credentials

# Check active NFS mounts
mount | grep "sec=krb5"
```

## Troubleshooting

### Pod Stuck in ContainerCreating

```bash
# Check pod events
kubectl describe pod <pod-name>

# Common causes:
# - NFS server unreachable
# - rpc-gssd not running on worker node
# - Keytab missing or incorrect
# - Network issues

# Check worker node
ssh root@<worker-node>
systemctl status rpc-gssd
klist -k /etc/krb5.keytab
ping file-server.cube.k8s
```

### Permission Denied

```bash
# Check NFS exports on server
ssh root@file-server.cube.k8s "cat /etc/exports"

# Verify Kerberos services
ssh root@file-server.cube.k8s "systemctl status rpc-svcgssd"

# Check worker node Kerberos
ssh root@<worker-node> "systemctl status rpc-gssd"
```

### Mount Fails

```bash
# On worker node, test manual mount
ssh root@<worker-node>
mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/socialpro /mnt/test

# Check logs
journalctl -xe | grep -i nfs
journalctl -u rpc-gssd -n 50
```

## Security Levels

You can modify the `mountOptions` in PV definitions to change security level:

### Basic Kerberos Authentication
```yaml
mountOptions:
  - vers=4
  - sec=krb5
```

### Kerberos with Integrity Checking
```yaml
mountOptions:
  - vers=4
  - sec=krb5i
```

### Kerberos with Encryption (Most Secure)
```yaml
mountOptions:
  - vers=4
  - sec=krb5p
```

## Performance Considerations

- **sec=krb5**: Lowest overhead, authentication only
- **sec=krb5i**: Medium overhead, adds integrity checking
- **sec=krb5p**: Highest overhead, adds encryption

Choose based on your security requirements and performance needs.

## Best Practices

1. **Use PV/PVC**: Prefer PersistentVolumes over direct NFS mounts for better management
2. **Resource Limits**: Always set resource limits on containers
3. **ReadWriteMany**: NFS supports multiple pods reading/writing simultaneously
4. **Monitoring**: Monitor NFS mount health and performance
5. **Backup**: Regularly backup data on NFS shares

## Additional Resources

- [Kubernetes NFS with Kerberos Examples](../../docs/kubernetes-nfs-kerberos-examples.md)
- [NFS Client Deployment](../../docs/nfs-client-deployment.md)
- [Kerberos NFS Setup Complete](../../docs/kerberos-nfs-setup-complete.md)
