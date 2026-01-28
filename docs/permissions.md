# NFS Permissions Guide

How NFS permissions work with Kubernetes pods.

## Current Configuration

### NFS Export Options

```
all_squash,anonuid=1001,anongid=100
```

- **`all_squash`**: Maps ALL client UIDs to anonymous user
- **`anonuid=1001`**: Anonymous user is UID 1001 (gustavo)
- **`anongid=100`**: Anonymous group is GID 100 (users)

### How It Works

```
Pod runs as UID 5000 → Mapped to UID 1001 (gustavo) → File created as gustavo:users → Success!
```

All files written from any pod are owned by `gustavo:users`, regardless of pod UID.

### Directory Permissions

```bash
drwxrwxr-x gustavo users /srv/shares/socialpro
drwxrwxr-x gustavo users /srv/shares/photos-vol
drwxrwxr-x gustavo users /srv/shares/photos-lib
```

## Benefits

- ✅ No permission issues
- ✅ No chown needed
- ✅ Works with any pod UID
- ✅ Consistent file ownership
- ✅ Still requires Kerberos auth

## Kubernetes Pod Config

**No special securityContext needed:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: nfs
      mountPath: /data
  volumes:
  - name: nfs
    nfs:
      server: file-server.cube.k8s
      path: /srv/shares/photos-lib
```

## Troubleshooting

### Files showing wrong ownership

```bash
# Remount on worker node
ssh root@k8s-worker-01
umount /mnt/path
mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/path /mnt/path

# Or restart pod
kubectl delete pod <pod-name>
```

### Permission denied errors

```bash
# Check directory permissions on server
ssh root@file-server.cube.k8s "ls -la /srv/shares/"

# Fix if needed
ssh root@file-server.cube.k8s "chown -R gustavo:users /srv/shares/photos-lib && chmod -R 775 /srv/shares/photos-lib"
```

### Verify exports

```bash
ssh root@file-server.cube.k8s "exportfs -v"
# Should show: all_squash,anonuid=1001,anongid=100
```

## Alternative: Per-User Mapping

If you need different users for different shares:

```yaml
nfs_exports:
  - path: "/srv/shares/socialpro"
    clients:
      - host: "*"
        options: "rw,sync,sec=krb5:krb5i:krb5p,all_squash,anonuid=1001,anongid=100"
  - path: "/srv/shares/photos"
    clients:
      - host: "*"
        options: "rw,sync,sec=krb5:krb5i:krb5p,all_squash,anonuid=1002,anongid=100"
```

## Alternative: No Squashing

For advanced setups preserving UIDs:

```yaml
options: "rw,sync,sec=krb5:krb5i:krb5p,no_root_squash,no_all_squash"
```

**Requires:**
- Matching UIDs on server and clients
- Proper user management
- More complex setup
