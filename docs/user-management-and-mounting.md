# User Management and SMB Share Mounting Guide

## Table of Contents
1. [Creating Kerberos Users](#creating-kerberos-users)
2. [Mounting SMB Shares](#mounting-smb-shares)
3. [Troubleshooting](#troubleshooting)

---

## Creating Kerberos Users

Since your file server uses Kerberos authentication, users must exist in your Kerberos KDC (Key Distribution Center).

### Option 1: Using kadmin (Remote Administration)

If you have admin credentials for the KDC:

```bash
# Connect to KDC as admin
kadmin -p admin/admin@CUBE.K8S

# Create a new user principal
kadmin: addprinc username@CUBE.K8S
# You'll be prompted to set a password

# List all principals to verify
kadmin: listprincs

# Exit kadmin
kadmin: quit
```

### Option 2: Using kadmin.local (Direct KDC Access)

If you have root access on the KDC server:

```bash
# SSH to your KDC server (kdc.cube.k8s)
ssh root@kdc.cube.k8s

# Use kadmin.local (no authentication needed)
kadmin.local

# Create a new user principal
kadmin.local: addprinc username@CUBE.K8S
# Enter password when prompted

# Create multiple users
kadmin.local: addprinc alice@CUBE.K8S
kadmin.local: addprinc bob@CUBE.K8S
kadmin.local: addprinc admin@CUBE.K8S

# Exit
kadmin.local: quit
```

### Creating a Group of Users

```bash
# On the KDC
kadmin.local

# Create user principals
addprinc alice@CUBE.K8S
addprinc bob@CUBE.K8S
addprinc charlie@CUBE.K8S

# Exit kadmin
quit
```

### Creating System Users on File Server

Users also need to exist as system users on the file server for proper file ownership:

```bash
# SSH to your file server
ssh root@fileserver01

# Create a users group
groupadd users

# Create system users (matching Kerberos principals)
useradd -m -g users alice
useradd -m -g users bob
useradd -m -g users charlie

# Create an admin user
useradd -m -G users admin
```

**Note:** The system usernames should match the Kerberos principal names (before the @REALM).

---

## Mounting SMB Shares

### Prerequisites

On the client machine, you need:

```bash
# For Debian/Ubuntu
sudo apt-get update
sudo apt-get install cifs-utils krb5-user

# For RHEL/CentOS/Rocky
sudo dnf install cifs-utils krb5-workstation

# For macOS (built-in, just need Kerberos config)
# Edit /etc/krb5.conf
```

### Configure Kerberos Client

Create or edit `/etc/krb5.conf` on your client:

```ini
[libdefaults]
    default_realm = CUBE.K8S
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    CUBE.K8S = {
        kdc = kdc.cube.k8s
        admin_server = kdc.cube.k8s
    }

[domain_realm]
    .cube.k8s = CUBE.K8S
    cube.k8s = CUBE.K8S
```

### Method 1: Manual Mount with Kerberos

```bash
# 1. Obtain a Kerberos ticket
kinit username@CUBE.K8S
# Enter your password

# 2. Verify you have a ticket
klist
# Should show: Ticket cache: FILE:/tmp/krb5cc_...
#              Default principal: username@CUBE.K8S

# 3. Mount the SMB share with Kerberos
sudo mkdir -p /mnt/socialpro
sudo mount -t cifs //fileserver01.cube.k8s/socialpro /mnt/socialpro \
    -o sec=krb5,user=username,uid=$(id -u),gid=$(id -g)

# 4. Verify the mount
df -h | grep socialpro
ls -la /mnt/socialpro
```

### Method 2: Persistent Mount via /etc/fstab

For automatic mounting at boot:

```bash
# 1. Create mount point
sudo mkdir -p /mnt/socialpro

# 2. Edit /etc/fstab
sudo nano /etc/fstab

# 3. Add this line:
//fileserver01.cube.k8s/socialpro  /mnt/socialpro  cifs  sec=krb5,user=username,uid=1000,gid=1000,noauto,x-systemd.automount  0  0

# 4. Test the mount
sudo mount -a
```

**Note:** For persistent mounts, you'll need to ensure Kerberos tickets are renewed automatically (see below).

### Method 3: User-Space Mount (No Root Required)

Using `mount.cifs` with user permissions:

```bash
# 1. Get Kerberos ticket
kinit username@CUBE.K8S

# 2. Create mount point in your home directory
mkdir ~/socialpro

# 3. Mount (if your system allows user mounts)
mount -t cifs //fileserver01.cube.k8s/socialpro ~/socialpro \
    -o sec=krb5,user=username,uid=$(id -u),gid=$(id -g)
```

### Method 4: macOS Mount

```bash
# 1. Configure Kerberos (edit /etc/krb5.conf as shown above)

# 2. Obtain ticket
kinit username@CUBE.K8S

# 3. Mount via Finder
# - Open Finder
# - Press Cmd+K (or Go > Connect to Server)
# - Enter: smb://fileserver01.cube.k8s/socialpro
# - Click Connect (should use Kerberos automatically)

# Or via command line:
mkdir ~/Desktop/socialpro
mount -t smbfs //username@fileserver01.cube.k8s/socialpro ~/Desktop/socialpro
```

### Method 5: Windows Mount

```powershell
# 1. Configure Kerberos
# Edit C:\ProgramData\MIT\Kerberos5\krb5.ini (if using MIT Kerberos for Windows)
# Or use Windows native Kerberos (if joined to domain)

# 2. Obtain ticket (if using MIT Kerberos)
kinit username@CUBE.K8S

# 3. Map network drive
net use Z: \\fileserver01.cube.k8s\socialpro

# Or via GUI:
# - Open File Explorer
# - Right-click "This PC" > "Map network drive"
# - Drive: Z:
# - Folder: \\fileserver01.cube.k8s\socialpro
# - Check "Connect using different credentials" if needed
```

---

## Security Levels

Your NFS exports support multiple Kerberos security levels. For SMB, you can specify:

```bash
# Kerberos authentication only (default)
mount -t cifs //server/share /mnt/point -o sec=krb5

# Kerberos with integrity checking
mount -t cifs //server/share /mnt/point -o sec=krb5i

# Kerberos with encryption (most secure)
mount -t cifs //server/share /mnt/point -o sec=krb5p
```

---

## Automatic Ticket Renewal

For persistent mounts, you need to keep your Kerberos tickets valid:

### Using k5start (Recommended)

```bash
# Install k5start
sudo apt-get install kstart  # Debian/Ubuntu
sudo dnf install kstart       # RHEL/CentOS

# Run k5start to keep ticket renewed
k5start -f /path/to/keytab -U -o username -K 60

# Or for user with password (less secure)
k5start -f ~/.k5login -U -o username -K 60
```

### Using cron with kinit

```bash
# Create a script to renew tickets
cat > ~/renew-ticket.sh << 'EOF'
#!/bin/bash
# Renew Kerberos ticket
kinit -R || kinit username@CUBE.K8S < ~/password.txt
EOF

chmod +x ~/renew-ticket.sh

# Add to crontab (runs every 6 hours)
crontab -e
# Add: 0 */6 * * * /home/username/renew-ticket.sh
```

**Security Warning:** Storing passwords in files is not recommended for production. Use keytabs instead.

---

## Unmounting Shares

```bash
# Unmount the share
sudo umount /mnt/socialpro

# Or force unmount if busy
sudo umount -f /mnt/socialpro

# Destroy Kerberos ticket when done
kdestroy
```

---

## Troubleshooting

### Issue: "Permission denied" when mounting

```bash
# Check Kerberos ticket
klist
# If no ticket or expired, run: kinit username@CUBE.K8S

# Verify DNS resolution
ping fileserver01.cube.k8s

# Check if SMB port is open
telnet fileserver01.cube.k8s 445
```

### Issue: "Host is down" or "Connection refused"

```bash
# Verify Samba is running on file server
ssh root@fileserver01
systemctl status smbd

# Check firewall
sudo ufw status
sudo ufw allow 445/tcp  # If needed
```

### Issue: "No such file or directory"

```bash
# List available shares
smbclient -L //fileserver01.cube.k8s -k
# The -k flag uses Kerberos

# Or without Kerberos (for testing)
smbclient -L //fileserver01.cube.k8s -U username
```

### Issue: "Required key not available"

This usually means Kerberos authentication failed:

```bash
# Check ticket is valid
klist -e

# Verify time sync (Kerberos requires synchronized clocks)
date
# Time difference should be < 5 minutes between client and KDC

# Sync time if needed
sudo ntpdate pool.ntp.org
# Or: sudo timedatectl set-ntp true
```

### Issue: User can't access files after mounting

```bash
# Check share permissions on server
ssh root@fileserver01
ls -la /srv/shares/socialpro

# Verify user exists on file server
id username

# Check Samba logs
tail -f /var/log/samba/log.fileserver01
```

### Debug Mode

Mount with verbose output:

```bash
# Enable CIFS debugging
echo 7 | sudo tee /proc/fs/cifs/cifsFYI

# Mount with verbose
sudo mount -t cifs //fileserver01.cube.k8s/socialpro /mnt/socialpro \
    -o sec=krb5,user=username,uid=$(id -u),gid=$(id -g),vers=3.0

# Check kernel messages
dmesg | tail -20
```

---

## Quick Reference

### Complete Workflow Example

```bash
# === ON KDC SERVER ===
# Create user
kadmin.local
addprinc alice@CUBE.K8S
quit

# === ON FILE SERVER ===
# Create system user
useradd -m -g users alice

# === ON CLIENT ===
# Configure Kerberos client (/etc/krb5.conf)
# Get ticket
kinit alice@CUBE.K8S

# Mount share
sudo mkdir -p /mnt/socialpro
sudo mount -t cifs //fileserver01.cube.k8s/socialpro /mnt/socialpro \
    -o sec=krb5,user=alice,uid=$(id -u),gid=$(id -g)

# Use the share
cd /mnt/socialpro
ls -la

# Unmount when done
sudo umount /mnt/socialpro
kdestroy
```

---

## Additional Resources

- **Samba Documentation**: https://www.samba.org/samba/docs/
- **MIT Kerberos**: https://web.mit.edu/kerberos/
- **CIFS Utils**: https://wiki.samba.org/index.php/LinuxCIFS_utils

For more information about your specific setup, check:
- File server configuration: `group_vars/fileservers.yml`
- Samba configuration: `roles/samba/templates/smb.conf.j2`
- Requirements: `.kiro/specs/file-server-ansible/requirements.md`
