# Client Setup Guide

Configure Linux and macOS clients to mount NFS/SMB shares with Kerberos.

## Linux (Debian/Ubuntu)

### Install Packages

```bash
sudo apt-get update
sudo apt-get install -y nfs-common krb5-user cifs-utils
```

### Configure Kerberos

Edit `/etc/krb5.conf`:

```ini
[libdefaults]
    default_realm = CUBE.K8S
    dns_lookup_realm = false
    dns_lookup_kdc = false

[realms]
    CUBE.K8S = {
        kdc = file-server.cube.k8s
        admin_server = file-server.cube.k8s
    }

[domain_realm]
    .cube.k8s = CUBE.K8S
    cube.k8s = CUBE.K8S
```

Add to `/etc/hosts` if DNS not configured:
```
10.10.10.110 file-server.cube.k8s file-server
```

### Mount NFS

```bash
# Get Kerberos ticket
kinit gustavo@CUBE.K8S

# Verify ticket
klist

# Create mount point
sudo mkdir -p /mnt/socialpro

# Mount with Kerberos
sudo mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/socialpro /mnt/socialpro

# Verify
ls -la /mnt/socialpro

# Unmount
sudo umount /mnt/socialpro
```

### Mount SMB

```bash
kinit gustavo@CUBE.K8S

sudo mkdir -p /mnt/socialpro
sudo mount -t cifs //file-server.cube.k8s/socialpro /mnt/socialpro \
    -o sec=krb5,user=gustavo,uid=$(id -u),gid=$(id -g)
```

### Persistent Mount (fstab)

Add to `/etc/fstab`:
```
file-server.cube.k8s:/srv/shares/socialpro  /mnt/socialpro  nfs  sec=krb5,vers=4,noauto,x-systemd.automount  0  0
```

Then:
```bash
sudo systemctl daemon-reload
sudo systemctl restart remote-fs.target
```

### Automatic Mount (autofs)

```bash
sudo apt-get install -y autofs

# Edit /etc/auto.master
/mnt/nfs  /etc/auto.nfs  --timeout=60

# Create /etc/auto.nfs
socialpro  -fstype=nfs,sec=krb5,vers=4  file-server.cube.k8s:/srv/shares/socialpro

sudo systemctl restart autofs
sudo systemctl enable autofs

# Access (auto-mounts)
cd /mnt/nfs/socialpro
```

## macOS

### Configure Kerberos

Edit `/etc/krb5.conf` (same as Linux above).

Add to `/etc/hosts`:
```
10.10.10.110 file-server.cube.k8s file-server
```

### Mount NFS

```bash
kinit gustavo@CUBE.K8S

sudo mkdir -p /Volumes/SocialPRO
sudo mount -t nfs -o resvport,sec=krb5 file-server.cube.k8s:/srv/shares/socialpro /Volumes/SocialPRO
```

### Mount SMB

```bash
kinit gustavo@CUBE.K8S

mkdir -p ~/SocialPRO
mount_smbfs -o sec=krb5 //gustavo@file-server.cube.k8s/socialpro ~/SocialPRO

# Or via Finder: Cmd+K → smb://file-server.cube.k8s/socialpro
```

## Security Options

| Option | Description |
|--------|-------------|
| `sec=krb5` | Authentication only |
| `sec=krb5i` | Authentication + integrity |
| `sec=krb5p` | Authentication + encryption (recommended) |

```bash
# Most secure mount
sudo mount -t nfs -o sec=krb5p,vers=4 file-server.cube.k8s:/srv/shares/socialpro /mnt/socialpro
```

## Troubleshooting

### "No credentials cache found"

```bash
kinit gustavo@CUBE.K8S
klist  # Verify ticket exists
```

### "Cannot find KDC for realm"

1. Check `/etc/krb5.conf` has correct KDC address
2. Verify network: `ping file-server.cube.k8s`
3. Check firewall allows port 88

### "Clock skew too great"

```bash
# Sync time (must be < 5 min difference)
sudo timedatectl set-ntp true
# macOS: sudo sntp -sS time.apple.com
```

### "access denied by server"

1. Check Kerberos ticket: `klist`
2. Verify export exists: `showmount -e file-server.cube.k8s`
3. Check server logs: `journalctl -u rpc-svcgssd`

### "Permission denied" after mount

```bash
# Check what user you're running as
id

# Files may be owned by different user
ls -la /mnt/socialpro
```

## Quick Reference

```bash
# Kerberos
kinit user@CUBE.K8S       # Get ticket
klist                     # List tickets
kdestroy                  # Destroy tickets

# NFS mount
sudo mount -t nfs -o sec=krb5,vers=4 server:/path /mnt/point

# SMB mount
sudo mount -t cifs -o sec=krb5 //server/share /mnt/point

# Unmount
sudo umount /mnt/point
```
