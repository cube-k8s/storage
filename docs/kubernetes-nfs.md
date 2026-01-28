# Kubernetes NFS Guide

Mount NFS shares with Kerberos in Kubernetes pods.

## Prerequisites

Worker nodes must have:
- NFS client packages installed
- Kerberos keytabs at `/etc/krb5.keytab`
- `rpc-gssd` service running

Deploy with:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/nfs-client.yml
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nfs-client-keytabs.yml
```

## Direct NFS Volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: nginx:latest
    volumeMounts:
    - name: nfs-storage
      mountPath: /mnt/data
  volumes:
  - name: nfs-storage
    nfs:
      server: file-server.cube.k8s
      path: /srv/shares/socialpro
```

## PersistentVolume + PVC

### PersistentVolume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-kerberos
  mountOptions:
    - vers=4
    - sec=krb5
  nfs:
    server: file-server.cube.k8s
    path: /srv/shares/socialpro
```

### PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-kerberos
  resources:
    requests:
      storage: 50Gi
```

### Pod Using PVC

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: nginx:latest
    volumeMounts:
    - name: data
      mountPath: /mnt/data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: nfs-pvc
```

## Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        volumeMounts:
        - name: shared-data
          mountPath: /usr/share/nginx/html
      volumes:
      - name: shared-data
        nfs:
          server: file-server.cube.k8s
          path: /srv/shares/socialpro
```

## Permissions

The NFS server uses `all_squash` to map all pod UIDs to `gustavo:users`:

```
all_squash,anonuid=1001,anongid=100
```

This means:
- Any pod UID → mapped to UID 1001 (gustavo)
- Files created are owned by `gustavo:users`
- No permission issues regardless of pod securityContext

**No special securityContext needed in pods.**

## Security Levels

```yaml
mountOptions:
  - vers=4
  - sec=krb5    # Authentication only
  # - sec=krb5i  # + integrity checking
  # - sec=krb5p  # + encryption (most secure)
```

## Testing

### Test Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nfs-test
spec:
  containers:
  - name: test
    image: busybox:latest
    command: ["sh", "-c", "while true; do echo $(date) >> /mnt/data/test.txt; sleep 5; done"]
    volumeMounts:
    - name: nfs-storage
      mountPath: /mnt/data
  volumes:
  - name: nfs-storage
    nfs:
      server: file-server.cube.k8s
      path: /srv/shares/socialpro
```

```bash
kubectl apply -f test-pod.yaml
kubectl exec -it nfs-test -- sh
ls -la /mnt/data
```

## Troubleshooting

### Pod Stuck in ContainerCreating

```bash
kubectl describe pod <pod-name>
```

Check:
1. NFS server reachable from worker node
2. `rpc-gssd` running on worker
3. Keytab exists at `/etc/krb5.keytab`

### "access denied by server"

```bash
# Find which worker node
kubectl get pod <pod-name> -o wide

# SSH to worker and test manually
ssh root@<worker-node>
mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/socialpro /mnt/test
```

### Check Worker Node

```bash
ssh root@k8s-worker-01

# Check keytab
klist -k /etc/krb5.keytab

# Check rpc-gssd
systemctl status rpc-gssd

# Check logs
journalctl -u rpc-gssd -n 50
```

### Keytab Out of Date

If you see "kvno X not found in keytab":

```bash
# Redeploy keytabs
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nfs-client-keytabs.yml
```

## Important Notes

1. **Host-based auth**: Pods use worker node's keytab, not per-pod credentials
2. **ReadWriteMany**: NFS supports multiple pods across nodes
3. **No user tickets**: Machine keytabs don't expire
4. **Performance**: `sec=krb5p` adds CPU overhead; use `sec=krb5` if encryption not needed
