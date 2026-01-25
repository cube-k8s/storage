# Kerberos KDC Setup Guide

## Overview

This guide walks you through deploying a MIT Kerberos Key Distribution Center (KDC) using Ansible. The KDC provides centralized authentication for your file server and clients.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Configuration](#configuration)
4. [Deployment](#deployment)
5. [Post-Installation](#post-installation)
6. [Managing Principals](#managing-principals)
7. [Integration with File Server](#integration-with-file-server)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### KDC Server Requirements

- Debian 11+ or Ubuntu 20.04+ server
- Minimum 1GB RAM, 10GB disk
- Static IP address
- Fully qualified domain name (FQDN)
- SSH access with root or sudo privileges

### Network Requirements

- Port 88 (TCP/UDP) - Kerberos authentication
- Port 464 (TCP/UDP) - Kerberos password changes
- Port 749 (TCP) - Kerberos admin (kadmin)

### Time Synchronization

**CRITICAL:** All systems (KDC, file server, clients) must have synchronized clocks within 5 minutes.

```bash
# Install NTP
sudo apt-get install ntp

# Or use systemd-timesyncd
sudo timedatectl set-ntp true

# Verify time sync
timedatectl status
```

---

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts.yml`:

```yaml
all:
  children:
    kdc:
      hosts:
        kdc01:
          ansible_host: 192.168.1.10  # Your KDC IP
          ansible_user: root
```

### 2. Configure Variables

Edit `group_vars/kdc.yml`:

```yaml
kdc_realm: "CUBE.K8S"
kdc_domain: "cube.k8s"
kdc_master_password: "YourStrongMasterPassword"
kdc_admin_password: "YourStrongAdminPassword"
```

**IMPORTANT:** Use strong passwords and encrypt with ansible-vault:

```bash
ansible-vault encrypt group_vars/kdc.yml
```

### 3. Deploy KDC

```bash
# Deploy the KDC
ansible-playbook playbooks/kdc.yml

# Or with vault password
ansible-playbook playbooks/kdc.yml --ask-vault-pass
```

### 4. Verify Installation

```bash
# SSH to KDC
ssh root@kdc01

# Test authentication
kinit admin/admin@CUBE.K8S
klist

# Should show:
# Ticket cache: FILE:/tmp/krb5cc_0
# Default principal: admin/admin@CUBE.K8S
```

---

## Configuration

### Realm and Domain

The **realm** is your Kerberos authentication domain (typically uppercase):

```yaml
kdc_realm: "CUBE.K8S"
```

The **domain** is your DNS domain (lowercase):

```yaml
kdc_domain: "cube.k8s"
```

### Security Settings

#### Master Password

The master password encrypts the Kerberos database:

```yaml
kdc_master_password: "VeryStrongRandomPassword"
```

**Best Practice:** Generate a strong random password:

```bash
openssl rand -base64 32
```

#### Admin Password

The admin principal password for KDC administration:

```yaml
kdc_admin_password: "AnotherStrongPassword"
```

#### Encryption Types

Modern, secure encryption (default):

```yaml
kdc_supported_enctypes:
  - "aes256-cts-hmac-sha1-96:normal"
  - "aes128-cts-hmac-sha1-96:normal"
```

### Ticket Lifetimes

```yaml
kdc_max_life: "24h 0m 0s"              # Maximum ticket lifetime
kdc_max_renewable_life: "7d 0h 0m 0s"  # Maximum renewable lifetime
```

### Access Control

Define who can administer the KDC:

```yaml
kdc_acl_entries:
  - principal: "*/admin@{{ kdc_realm }}"
    permissions: "*"
  - principal: "admin/admin@{{ kdc_realm }}"
    permissions: "*"
```

Permissions:
- `*` = all permissions
- `a` = add principals
- `d` = delete principals
- `m` = modify principals
- `c` = change passwords
- `i` = inquire (view)
- `l` = list principals

### Automatic Principal Creation

#### Service Principals

For file servers and other services:

```yaml
kdc_service_principals:
  - "nfs/fileserver01.cube.k8s@CUBE.K8S"
  - "cifs/fileserver01.cube.k8s@CUBE.K8S"
  - "host/fileserver01.cube.k8s@CUBE.K8S"
```

#### User Principals

For users (optional, can be created manually):

```yaml
kdc_user_principals:
  - name: "alice"
    password: "alice123"
  - name: "bob"
    password: "bob123"
```

**Note:** Storing user passwords in variables is not recommended for production. Create users manually instead.

---

## Deployment

### Standard Deployment

```bash
# Deploy KDC
ansible-playbook playbooks/kdc.yml

# Deploy only to specific host
ansible-playbook playbooks/kdc.yml --limit kdc01

# Check mode (dry run)
ansible-playbook playbooks/kdc.yml --check
```

### With Vault Encryption

```bash
# Encrypt sensitive variables
ansible-vault encrypt group_vars/kdc.yml

# Deploy with vault password
ansible-playbook playbooks/kdc.yml --ask-vault-pass

# Or use password file
ansible-playbook playbooks/kdc.yml --vault-password-file ~/.vault_pass
```

### Deployment with Tags

```bash
# Install packages only
ansible-playbook playbooks/kdc.yml --tags packages

# Configure only (skip installation)
ansible-playbook playbooks/kdc.yml --tags config

# Create principals only
ansible-playbook playbooks/kdc.yml --tags principals
```

---

## Post-Installation

### Verify KDC Services

```bash
# Check service status
systemctl status krb5-kdc
systemctl status krb5-admin-server

# Check listening ports
ss -tulpn | grep -E ':(88|464|749)'
```

### Test Authentication

```bash
# Get a ticket for admin
kinit admin/admin@CUBE.K8S

# List tickets
klist

# Verify ticket details
klist -e  # Show encryption types

# Destroy ticket
kdestroy
```

### Configure Firewall

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 88/tcp
sudo ufw allow 88/udp
sudo ufw allow 464/tcp
sudo ufw allow 464/udp
sudo ufw allow 749/tcp

# Or allow from specific network
sudo ufw allow from 192.168.1.0/24 to any port 88
```

---

## Managing Principals

### Using kadmin.local (Direct Access)

On the KDC server:

```bash
# Start kadmin.local (no authentication needed)
kadmin.local

# List all principals
kadmin.local: listprincs

# Add a user principal
kadmin.local: addprinc alice@CUBE.K8S
# Enter password when prompted

# Add a service principal (random key)
kadmin.local: addprinc -randkey nfs/fileserver.cube.k8s@CUBE.K8S

# View principal details
kadmin.local: getprinc alice@CUBE.K8S

# Modify principal
kadmin.local: modprinc -maxlife "12 hours" alice@CUBE.K8S

# Change password
kadmin.local: cpw alice@CUBE.K8S

# Delete principal
kadmin.local: delprinc alice@CUBE.K8S

# Exit
kadmin.local: quit
```

### Using kadmin (Remote Access)

From any machine with Kerberos client:

```bash
# Connect to KDC
kadmin -p admin/admin@CUBE.K8S

# Same commands as kadmin.local
kadmin: listprincs
kadmin: addprinc bob@CUBE.K8S
kadmin: quit
```

### Creating Service Principals and Keytabs

```bash
kadmin.local

# Create service principal
kadmin.local: addprinc -randkey nfs/fileserver01.cube.k8s@CUBE.K8S

# Export to keytab
kadmin.local: ktadd -k /tmp/fileserver.keytab nfs/fileserver01.cube.k8s@CUBE.K8S

# Add multiple principals to same keytab
kadmin.local: ktadd -k /tmp/fileserver.keytab cifs/fileserver01.cube.k8s@CUBE.K8S

kadmin.local: quit

# Verify keytab
klist -k /tmp/fileserver.keytab

# Set permissions
chmod 600 /tmp/fileserver.keytab
```

### Batch Principal Creation

```bash
# Create a file with principals
cat > /tmp/users.txt << EOF
alice@CUBE.K8S
bob@CUBE.K8S
charlie@CUBE.K8S
EOF

# Add them all
while read principal; do
  kadmin.local -q "addprinc -pw changeme $principal"
done < /tmp/users.txt
```

---

## Integration with File Server

### 1. Update File Server Variables

Edit `group_vars/fileservers.yml`:

```yaml
# Point to your KDC
krb5_realm: "CUBE.K8S"
krb5_kdc: "kdc01.cube.k8s"
krb5_admin_server: "kdc01.cube.k8s"
```

### 2. Create Service Principals

On the KDC:

```bash
kadmin.local

# Create principals for file server
addprinc -randkey nfs/fileserver01.cube.k8s@CUBE.K8S
addprinc -randkey cifs/fileserver01.cube.k8s@CUBE.K8S

# Export to keytab
ktadd -k /var/lib/krb5kdc/keytabs/fileserver01.keytab nfs/fileserver01.cube.k8s@CUBE.K8S
ktadd -k /var/lib/krb5kdc/keytabs/fileserver01.keytab cifs/fileserver01.cube.k8s@CUBE.K8S

quit
```

### 3. Copy Keytab to File Server

```bash
# From KDC
scp /var/lib/krb5kdc/keytabs/fileserver01.keytab root@fileserver01:/etc/krb5.keytab

# On file server, set permissions
ssh root@fileserver01
chmod 600 /etc/krb5.keytab
chown root:root /etc/krb5.keytab
```

### 4. Deploy File Server

```bash
# Deploy file server with Kerberos integration
ansible-playbook playbooks/site.yml
```

### 5. Verify Integration

```bash
# On file server, verify keytab
klist -k /etc/krb5.keytab

# Should show:
# Keytab name: FILE:/etc/krb5.keytab
# KVNO Principal
# ---- --------------------------------------------------------------------------
#    2 nfs/fileserver01.cube.k8s@CUBE.K8S
#    2 cifs/fileserver01.cube.k8s@CUBE.K8S
```

---

## Troubleshooting

### Issue: "Cannot contact any KDC"

**Cause:** Network connectivity or firewall issues

**Solution:**
```bash
# Test connectivity
telnet kdc01.cube.k8s 88

# Check firewall on KDC
sudo ufw status

# Verify KDC is running
systemctl status krb5-kdc
```

### Issue: "Clock skew too great"

**Cause:** Time difference > 5 minutes between systems

**Solution:**
```bash
# Check time on all systems
date

# Sync time
sudo ntpdate pool.ntp.org

# Or use systemd
sudo timedatectl set-ntp true
```

### Issue: "Principal does not exist"

**Cause:** Principal not created in KDC

**Solution:**
```bash
# List all principals
kadmin.local -q "listprincs"

# Create missing principal
kadmin.local -q "addprinc username@CUBE.K8S"
```

### Issue: "Decrypt integrity check failed"

**Cause:** Wrong password or corrupted keytab

**Solution:**
```bash
# For user principals, reset password
kadmin.local -q "cpw username@CUBE.K8S"

# For service principals, regenerate keytab
kadmin.local -q "ktadd -k /tmp/new.keytab service/host@REALM"
```

### Issue: "Cannot resolve network address"

**Cause:** DNS or hostname resolution issues

**Solution:**
```bash
# Verify FQDN
hostname -f

# Check DNS resolution
nslookup kdc01.cube.k8s

# Add to /etc/hosts if needed
echo "192.168.1.10 kdc01.cube.k8s kdc01" >> /etc/hosts
```

### Debug Mode

Enable detailed logging:

```bash
# Edit /etc/krb5.conf
[logging]
    kdc = FILE:/var/log/krb5kdc.log
    admin_server = FILE:/var/log/kadmin.log
    default = SYSLOG:INFO:DAEMON

# Restart services
systemctl restart krb5-kdc krb5-admin-server

# Watch logs
tail -f /var/log/krb5kdc.log
```

---

## Security Best Practices

### 1. Use Strong Passwords

```bash
# Generate strong passwords
openssl rand -base64 32
```

### 2. Encrypt Sensitive Variables

```bash
# Encrypt group_vars
ansible-vault encrypt group_vars/kdc.yml

# Edit encrypted file
ansible-vault edit group_vars/kdc.yml
```

### 3. Restrict Network Access

```bash
# Allow only from trusted networks
sudo ufw allow from 192.168.1.0/24 to any port 88
sudo ufw allow from 192.168.1.0/24 to any port 464
```

### 4. Regular Backups

```bash
# Backup Kerberos database
kdb5_util dump /backup/krb5-$(date +%Y%m%d).dump

# Backup configuration
tar -czf /backup/krb5-config-$(date +%Y%m%d).tar.gz /etc/krb5kdc /etc/krb5.conf
```

### 5. Monitor Logs

```bash
# Watch for failed authentication attempts
tail -f /var/log/krb5kdc.log | grep -i fail

# Check for unusual activity
grep "FAILED" /var/log/krb5kdc.log
```

---

## Quick Reference

### Common Commands

```bash
# Get ticket
kinit username@REALM

# List tickets
klist

# Renew ticket
kinit -R

# Destroy ticket
kdestroy

# Test KDC connectivity
kinit -V username@REALM

# List principals
kadmin.local -q "listprincs"

# Add user
kadmin.local -q "addprinc username@REALM"

# Add service
kadmin.local -q "addprinc -randkey service/host@REALM"

# Export keytab
kadmin.local -q "ktadd -k /path/to/file.keytab principal@REALM"

# View keytab
klist -k /path/to/file.keytab
```

### File Locations

- KDC configuration: `/etc/krb5kdc/kdc.conf`
- Client configuration: `/etc/krb5.conf`
- ACL configuration: `/etc/krb5kdc/kadm5.acl`
- Database: `/var/lib/krb5kdc/principal`
- Logs: `/var/log/krb5kdc.log`, `/var/log/kadmin.log`
- Keytabs: `/var/lib/krb5kdc/keytabs/`

---

## Additional Resources

- [MIT Kerberos Documentation](https://web.mit.edu/kerberos/krb5-latest/doc/)
- [Kerberos: The Definitive Guide](https://www.oreilly.com/library/view/kerberos-the-definitive/0596004036/)
- [Debian Kerberos Wiki](https://wiki.debian.org/Kerberos)

For file server integration, see:
- `docs/user-management-and-mounting.md`
- `docs/task-6.3-implementation.md`
