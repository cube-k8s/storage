# All-in-One Setup: KDC + File Server on Same Host

This guide shows you how to deploy both the Kerberos KDC and file server on a single host, which is ideal for home lab environments.

## Overview

Running the KDC and file server on the same host:
- ✅ Simplifies deployment (one server instead of two)
- ✅ Reduces hardware requirements
- ✅ Perfect for home labs and small environments
- ✅ Easier to manage and maintain
- ⚠️ Single point of failure (acceptable for home labs)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Single Server (file-server.cube.k8s)                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Kerberos KDC                                          │ │
│  │  - Port 88 (Kerberos auth)                             │ │
│  │  - Port 464 (Password changes)                         │ │
│  │  - Port 749 (Admin)                                    │ │
│  │  - Database: /var/lib/krb5kdc/                         │ │
│  │  - Principals: users + services                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                           │                                  │
│                           │ Local authentication             │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  File Server                                           │ │
│  │  ┌──────────────┐              ┌──────────────┐       │ │
│  │  │    Samba     │              │     NFS      │       │ │
│  │  │  Port 445    │              │  Port 2049   │       │ │
│  │  │  SMB/CIFS    │              │   NFSv4      │       │ │
│  │  └──────────────┘              └──────────────┘       │ │
│  │                                                        │ │
│  │  Keytab: /etc/krb5.keytab                             │ │
│  │  Shares: /srv/shares/                                 │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │ Kerberos + SMB/NFS
                           │
                    ┌──────┴──────┐
                    │   Clients   │
                    └─────────────┘
```

## Prerequisites

- One Debian 11+ or Ubuntu 20.04+ server
- Minimum 2GB RAM, 20GB disk
- Static IP address
- Fully qualified domain name (FQDN)
- SSH access with root privileges
- Ansible installed on your control machine

## Quick Start

### Step 1: Verify Inventory

Your `inventory/hosts.yml` should look like this:

```yaml
all:
  children:
    # KDC and file server running on the same host
    kdc:
      hosts:
        fileserver01:
          ansible_host: file-server.cube.k8s
          ansible_user: root
    
    fileservers:
      hosts:
        fileserver01:
          ansible_host: file-server.cube.k8s
          ansible_user: root
```

**Note:** The same host (`fileserver01`) is in both groups.

### Step 2: Configure KDC Variables

Edit `group_vars/kdc.yml`:

```yaml
kdc_realm: "CUBE.K8S"
kdc_domain: "cube.k8s"
kdc_master_password: "YourStrongMasterPassword"
kdc_admin_password: "YourStrongAdminPassword"

# Service principals (automatically created)
kdc_service_principals:
  - "nfs/file-server.cube.k8s@CUBE.K8S"
  - "cifs/file-server.cube.k8s@CUBE.K8S"

# User principals (optional)
kdc_user_principals:
  - name: "alice"
    password: "alice123"
  - name: "bob"
    password: "bob123"
```

### Step 3: Configure File Server Variables

Edit `group_vars/fileservers.yml`:

```yaml
# Kerberos configuration
krb5_realm: "CUBE.K8S"
krb5_kdc: "file-server.cube.k8s"  # Points to localhost
krb5_admin_server: "file-server.cube.k8s"

# Samba configuration
samba_workgroup: "CUBE"
samba_realm: "CUBE.K8S"
samba_local_kdc: true  # IMPORTANT: KDC is on same host

# Shares
samba_shares:
  - name: "socialpro"
    path: "/srv/shares/socialpro"
    comment: "SocialPRO file share"
    read_only: no
    browseable: yes
    valid_users: "@users"

shares:
  - path: "/srv/shares/socialpro"
    owner: "root"
    group: "users"
    mode: "0775"
```

**Important:** Set `samba_local_kdc: true` to ensure proper service dependencies.

### Step 4: Secure Your Configuration

```bash
# Encrypt sensitive variables
ansible-vault encrypt group_vars/kdc.yml

# Verify encryption
cat group_vars/kdc.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256...
```

### Step 5: Deploy Everything

```bash
# Using the deployment script (recommended)
./scripts/deploy-all-in-one.sh

# Or manually
ansible-playbook playbooks/all-in-one.yml --ask-vault-pass
```

### Step 6: Verify Deployment

```bash
# SSH to your server
ssh root@file-server.cube.k8s

# Check KDC is running
systemctl status krb5-kdc
systemctl status krb5-admin-server

# Check file services are running
systemctl status smbd
systemctl status nmbd

# Test Kerberos authentication
kinit admin/admin@CUBE.K8S
klist

# List principals
kadmin.local -q "listprincs"

# Verify keytab
klist -k /etc/krb5.keytab
# Should show nfs/ and cifs/ principals
```

## Deployment Sequence

The all-in-one playbook deploys in this order:

```
1. Deploy Kerberos KDC
   ├─ Install KDC packages
   ├─ Initialize database
   ├─ Create admin principal
   ├─ Create service principals (nfs, cifs)
   ├─ Export keytabs to /var/lib/krb5kdc/keytabs/
   └─ Start KDC services

2. Wait for KDC to be ready
   └─ Check port 88 is listening

3. Deploy File Server
   ├─ Install base packages (common role)
   ├─ Configure Kerberos client
   ├─ Copy keytabs from KDC export directory
   ├─ Create share directories
   ├─ Configure Samba with Kerberos
   ├─ Configure NFS with Kerberos
   └─ Start file services
```

## Key Configuration Differences

### When KDC is Local

**Samba systemd dependencies:**
```yaml
samba_local_kdc: true
```

This ensures Samba waits for the local KDC to start:
```ini
[Unit]
After=network.target
After=krb5-kdc.service  # Added when samba_local_kdc=true
```

**Keytab location:**
The keytabs are automatically available since they're on the same host:
- Exported to: `/var/lib/krb5kdc/keytabs/`
- Installed to: `/etc/krb5.keytab`

**KDC address:**
Points to localhost/FQDN:
```yaml
krb5_kdc: "file-server.cube.k8s"  # Same as server FQDN
```

## Post-Deployment Tasks

### 1. Create System Users

Users need to exist both in Kerberos and as system users:

```bash
# SSH to server
ssh root@file-server.cube.k8s

# Create group
groupadd users

# Create system users (matching Kerberos principals)
useradd -m -g users alice
useradd -m -g users bob
useradd -m -g users admin
```

### 2. Create Additional Kerberos Users

```bash
# On the server
kadmin.local

# Add users
addprinc charlie@CUBE.K8S
addprinc david@CUBE.K8S

# Exit
quit
```

### 3. Test from a Client

On a client machine:

```bash
# Configure Kerberos client
sudo vim /etc/krb5.conf
```

Add:
```ini
[libdefaults]
    default_realm = CUBE.K8S

[realms]
    CUBE.K8S = {
        kdc = file-server.cube.k8s
        admin_server = file-server.cube.k8s
    }

[domain_realm]
    .cube.k8s = CUBE.K8S
    cube.k8s = CUBE.K8S
```

Test:
```bash
# Get ticket
kinit alice@CUBE.K8S

# Verify
klist

# Mount share
sudo mkdir -p /mnt/socialpro
sudo mount -t cifs //file-server.cube.k8s/socialpro /mnt/socialpro \
    -o sec=krb5,user=alice,uid=$(id -u),gid=$(id -g)

# Test access
ls -la /mnt/socialpro
```

## Management Tasks

### View All Principals

```bash
ssh root@file-server.cube.k8s
kadmin.local -q "listprincs"
```

### Add a New User

```bash
# Create Kerberos principal
kadmin.local -q "addprinc newuser@CUBE.K8S"

# Create system user
useradd -m -g users newuser
```

### Change User Password

```bash
kadmin.local -q "cpw alice@CUBE.K8S"
```

### View Keytab Contents

```bash
klist -k /etc/krb5.keytab
```

### Check Service Status

```bash
# KDC services
systemctl status krb5-kdc
systemctl status krb5-admin-server

# File services
systemctl status smbd
systemctl status nmbd
systemctl status nfs-server

# All at once
systemctl status krb5-kdc krb5-admin-server smbd nmbd
```

### View Logs

```bash
# KDC logs
tail -f /var/log/krb5kdc.log

# Samba logs
tail -f /var/log/samba/log.*

# All authentication attempts
grep -i "authentication" /var/log/krb5kdc.log /var/log/samba/log.*
```

## Troubleshooting

### Issue: Services fail to start in correct order

**Solution:** Ensure `samba_local_kdc: true` is set in `group_vars/fileservers.yml`

```bash
# Check systemd dependencies
systemctl show smbd | grep After
# Should include: After=krb5-kdc.service
```

### Issue: Keytab not found

**Solution:** Verify keytab was created and has correct permissions

```bash
# Check if keytab exists
ls -la /etc/krb5.keytab

# Check keytab contents
klist -k /etc/krb5.keytab

# Check exported keytabs
ls -la /var/lib/krb5kdc/keytabs/

# Manually copy if needed
cp /var/lib/krb5kdc/keytabs/*.keytab /etc/krb5.keytab
chmod 600 /etc/krb5.keytab
```

### Issue: "Cannot contact any KDC" from clients

**Solution:** Check firewall and network

```bash
# On server, check KDC is listening
ss -tulpn | grep :88

# Allow firewall
sudo ufw allow 88/tcp
sudo ufw allow 88/udp
sudo ufw allow 445/tcp
sudo ufw allow 2049/tcp

# From client, test connectivity
telnet file-server.cube.k8s 88
```

### Issue: "Clock skew too great"

**Solution:** Synchronize time

```bash
# On server and all clients
sudo timedatectl set-ntp true
date

# Time difference must be < 5 minutes
```

## Backup and Recovery

### Backup Kerberos Database

```bash
# Create backup
kdb5_util dump /backup/krb5-$(date +%Y%m%d).dump

# Backup configuration
tar -czf /backup/krb5-config-$(date +%Y%m%d).tar.gz \
    /etc/krb5kdc /etc/krb5.conf /etc/krb5.keytab
```

### Restore Kerberos Database

```bash
# Stop KDC
systemctl stop krb5-kdc krb5-admin-server

# Restore database
kdb5_util load /backup/krb5-20240122.dump

# Start KDC
systemctl start krb5-kdc krb5-admin-server
```

## Performance Considerations

### Resource Usage

For a typical home lab with 5-10 users:
- RAM: 2GB sufficient
- CPU: 1-2 cores sufficient
- Disk: 20GB sufficient

### Optimization

The all-in-one setup is optimized for:
- Low latency (KDC and file server on same host)
- Reduced network traffic (no KDC network calls)
- Simplified management (one server to maintain)

## Security Considerations

### Single Point of Failure

Since KDC and file server are on the same host:
- ⚠️ If the server goes down, both authentication and file access are unavailable
- ✅ Acceptable for home labs and development
- ⚠️ For production, consider separate KDC servers with replication

### Firewall Configuration

```bash
# Allow required ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 88/tcp    # Kerberos
sudo ufw allow 88/udp    # Kerberos
sudo ufw allow 464/tcp   # Kerberos password
sudo ufw allow 464/udp   # Kerberos password
sudo ufw allow 445/tcp   # SMB
sudo ufw allow 2049/tcp  # NFS

# Or allow from specific network
sudo ufw allow from 192.168.1.0/24
```

### Regular Maintenance

- Backup Kerberos database weekly
- Monitor logs for failed authentication attempts
- Keep system updated: `apt update && apt upgrade`
- Rotate admin passwords periodically

## Advantages of All-in-One Setup

✅ **Simplicity:** One server to manage  
✅ **Cost:** Reduced hardware requirements  
✅ **Performance:** No network latency for KDC calls  
✅ **Maintenance:** Easier to backup and restore  
✅ **Perfect for:** Home labs, development, small teams  

## When to Use Separate KDC

Consider a separate KDC server if:
- You need high availability
- You have multiple file servers
- You need KDC redundancy
- You're running in production
- You have compliance requirements

## Quick Reference

```bash
# Deploy everything
./scripts/deploy-all-in-one.sh

# Check all services
systemctl status krb5-kdc krb5-admin-server smbd nmbd

# Create user
kadmin.local -q "addprinc user@REALM"
useradd -m -g users user

# Test authentication
kinit user@REALM
klist

# Mount share
mount -t cifs //server/share /mnt/point -o sec=krb5,user=user

# View logs
tail -f /var/log/krb5kdc.log /var/log/samba/log.*

# Backup
kdb5_util dump /backup/krb5-$(date +%Y%m%d).dump
```

## Additional Resources

- [KDC Setup Guide](kdc-setup-guide.md) - Detailed KDC configuration
- [User Management Guide](user-management-and-mounting.md) - Creating users and mounting shares
- [Architecture Diagram](architecture-diagram.md) - Visual system overview

---

**Need help?** Check the troubleshooting section or review the logs at `/var/log/krb5kdc.log` and `/var/log/samba/`.
