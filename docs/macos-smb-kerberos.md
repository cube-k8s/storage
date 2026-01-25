# macOS SMB with Kerberos Authentication

## Overview

Mounting SMB shares on macOS with Kerberos authentication requires specific configuration and commands.

## Prerequisites

1. Kerberos client configured (`/etc/krb5.conf`)
2. Valid Kerberos ticket obtained with `kinit`
3. Network connectivity to file server

## Configuration

### 1. Configure /etc/krb5.conf

Edit `/etc/krb5.conf` (requires sudo):

```bash
sudo nano /etc/krb5.conf
```

Add:

```ini
[libdefaults]
    default_realm = CUBE.K8S
    dns_lookup_realm = false
    dns_lookup_kdc = false
    forwardable = true
    proxiable = true

[realms]
    CUBE.K8S = {
        kdc = kdc.cube.k8s
        admin_server = kdc.cube.k8s
    }

[domain_realm]
    .cube.k8s = CUBE.K8S
    cube.k8s = CUBE.K8S
```

### 2. Configure /etc/hosts

Add the file server to `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Add:

```
10.10.10.110 file-server.cube.k8s file-server kdc.cube.k8s kdc
```

## Mounting SMB Share

### Method 1: Using mount_smbfs (Command Line)

```bash
# 1. Obtain Kerberos ticket
kinit gustavo@CUBE.K8S
# Password: JpMMf@Gm0

# 2. Verify ticket
klist

# 3. Create mount point
mkdir -p ~/SocialPRO

# 4. Mount with Kerberos
mount_smbfs -o sec=krb5 //gustavo@file-server.cube.k8s/socialpro ~/SocialPRO

# 5. Verify
ls -la ~/SocialPRO

# 6. Unmount when done
umount ~/SocialPRO
kdestroy
```

### Method 2: Using Finder (GUI)

1. **Obtain Kerberos ticket**:
   ```bash
   kinit gustavo@CUBE.K8S
   ```

2. **Open Finder** → **Go** → **Connect to Server** (⌘K)

3. **Enter server address**:
   ```
   smb://file-server.cube.k8s/socialpro
   ```

4. **Click Connect**

5. **Authentication**: Should use Kerberos automatically (no password prompt)

### Method 3: Using open command

```bash
# Obtain ticket
kinit gustavo@CUBE.K8S

# Open in Finder
open smb://file-server.cube.k8s/socialpro
```

## Troubleshooting

### Error: "Authentication error" or "Server rejected the connection"

**Possible causes**:

1. **No Kerberos ticket**:
   ```bash
   klist  # Check if you have a valid ticket
   kinit gustavo@CUBE.K8S  # Obtain ticket
   ```

2. **Wrong hostname**: macOS Kerberos is sensitive to hostnames
   - Use FQDN: `file-server.cube.k8s` (not just `file-server` or IP)
   - Ensure hostname matches the CIFS principal in keytab

3. **Keytab principal mismatch**:
   ```bash
   # On server, check keytab
   klist -k /etc/krb5.keytab | grep cifs
   # Should show: cifs/file-server.cube.k8s@CUBE.K8S
   ```

4. **Samba not configured for Kerberos**:
   ```bash
   # On server, check smb.conf
   grep -E '(realm|kerberos)' /etc/samba/smb.conf
   # Should show:
   # realm = CUBE.K8S
   # kerberos method = secrets and keytab
   ```

5. **Clock skew**: Time difference > 5 minutes
   ```bash
   # Check time
   date
   # Sync if needed (requires admin)
   sudo sntp -sS time.apple.com
   ```

### Error: "Operation not permitted"

Mount point permissions issue:

```bash
# Use a directory you own
mkdir -p ~/SocialPRO
mount_smbfs -o sec=krb5 //gustavo@file-server.cube.k8s/socialpro ~/SocialPRO
```

### Error: "No such file or directory"

Share doesn't exist or wrong name:

```bash
# List available shares (requires smbclient)
smbclient -L file-server.cube.k8s -k

# Or check server configuration
ssh root@file-server.cube.k8s
grep '^\[' /etc/samba/smb.conf
```

### Verify Kerberos is Working

```bash
# 1. Check ticket
klist

# 2. Check DNS/hostname resolution
ping file-server.cube.k8s

# 3. Check SMB port
nc -zv file-server.cube.k8s 445

# 4. Test with smbclient (if installed)
smbclient //file-server.cube.k8s/socialpro -k
```

## macOS-Specific Notes

1. **Hostname Resolution**: macOS Kerberos requires proper hostname resolution. Always use FQDN.

2. **Keychain Integration**: macOS may store Kerberos tickets in Keychain. Use `klist` to verify.

3. **Security Preferences**: macOS may block SMB connections. Check System Preferences → Security & Privacy.

4. **SMB Version**: macOS prefers SMB2/SMB3. Ensure server supports it (already configured).

## Alternative: NFS Mount on macOS

If SMB continues to have issues, try NFS:

```bash
# 1. Obtain Kerberos ticket
kinit gustavo@CUBE.K8S

# 2. Create mount point
mkdir -p ~/SocialPRO

# 3. Mount NFS with Kerberos
sudo mount -t nfs -o sec=krb5,resvport file-server.cube.k8s:/srv/shares/socialpro ~/SocialPRO

# 4. Verify
ls -la ~/SocialPRO

# 5. Unmount
sudo umount ~/SocialPRO
```

## Debugging Commands

```bash
# Check Kerberos configuration
cat /etc/krb5.conf

# Check Kerberos ticket
klist -v

# Check hostname resolution
nslookup file-server.cube.k8s
ping file-server.cube.k8s

# Check SMB connectivity
nc -zv file-server.cube.k8s 445

# Check time sync
sntp -d time.apple.com

# View system logs
log show --predicate 'subsystem == "com.apple.smb"' --last 5m
```

## Working Example

```bash
# Complete workflow
sudo nano /etc/hosts  # Add: 10.10.10.110 file-server.cube.k8s kdc.cube.k8s
sudo nano /etc/krb5.conf  # Configure as shown above
kinit gustavo@CUBE.K8S  # Password: JpMMf@Gm0
klist  # Verify ticket
mkdir -p ~/SocialPRO
mount_smbfs -o sec=krb5 //gustavo@file-server.cube.k8s/socialpro ~/SocialPRO
ls ~/SocialPRO
# Use the share...
umount ~/SocialPRO
kdestroy
```

## Security Notes

1. Always destroy tickets when done: `kdestroy`
2. Tickets expire after 24 hours (default)
3. Use secure passwords for Kerberos principals
4. Don't share Kerberos tickets between users
