# Kerberos KDC Quick Start

Get your Kerberos KDC up and running in 5 minutes.

## Prerequisites

- Debian/Ubuntu server with SSH access
- Ansible installed on your control machine
- Static IP and FQDN for KDC server

## Step 1: Configure Inventory

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

## Step 2: Configure Variables

Edit `group_vars/kdc.yml`:

```yaml
kdc_realm: "CUBE.K8S"
kdc_domain: "cube.k8s"
kdc_master_password: "YourStrongMasterPassword"
kdc_admin_password: "YourStrongAdminPassword"

# Optional: Create service principals automatically
kdc_service_principals:
  - "nfs/fileserver01.cube.k8s@CUBE.K8S"
  - "cifs/fileserver01.cube.k8s@CUBE.K8S"

# Optional: Create user principals automatically
kdc_user_principals:
  - name: "alice"
    password: "alice123"
  - name: "bob"
    password: "bob123"
```

## Step 3: Secure Your Passwords

```bash
# Encrypt the variables file
ansible-vault encrypt group_vars/kdc.yml
```

## Step 4: Deploy

```bash
# Using the deployment script
./scripts/deploy-kdc.sh

# Or manually
ansible-playbook playbooks/kdc.yml --ask-vault-pass
```

## Step 5: Verify

```bash
# SSH to KDC
ssh root@kdc01

# Test authentication
kinit admin/admin@CUBE.K8S
# Enter password when prompted

# List your ticket
klist

# Success! You should see:
# Ticket cache: FILE:/tmp/krb5cc_0
# Default principal: admin/admin@CUBE.K8S
```

## Step 6: Retrieve Keytabs for File Server

```bash
# On KDC, keytabs are exported to:
ls -la /var/lib/krb5kdc/keytabs/

# Copy to file server
scp /var/lib/krb5kdc/keytabs/nfs_fileserver01.cube.k8s_CUBE.K8S.keytab \
    root@fileserver01:/etc/krb5.keytab

# Or create a combined keytab manually:
kadmin.local
ktadd -k /tmp/fileserver.keytab nfs/fileserver01.cube.k8s@CUBE.K8S
ktadd -k /tmp/fileserver.keytab cifs/fileserver01.cube.k8s@CUBE.K8S
quit

scp /tmp/fileserver.keytab root@fileserver01:/etc/krb5.keytab
```

## Step 7: Update File Server Configuration

Edit `group_vars/fileservers.yml`:

```yaml
krb5_realm: "CUBE.K8S"
krb5_kdc: "kdc01.cube.k8s"
krb5_admin_server: "kdc01.cube.k8s"
```

## Step 8: Deploy File Server

```bash
ansible-playbook playbooks/site.yml
```

## Common Tasks

### Create a New User

```bash
ssh root@kdc01
kadmin.local
addprinc alice@CUBE.K8S
quit
```

### List All Principals

```bash
kadmin.local -q "listprincs"
```

### Create Service Principal

```bash
kadmin.local
addprinc -randkey nfs/newserver.cube.k8s@CUBE.K8S
ktadd -k /tmp/newserver.keytab nfs/newserver.cube.k8s@CUBE.K8S
quit
```

### Change User Password

```bash
kadmin.local
cpw alice@CUBE.K8S
quit
```

## Troubleshooting

### "Cannot contact any KDC"

Check firewall and network connectivity:

```bash
# On KDC
systemctl status krb5-kdc
ss -tulpn | grep :88

# From client
telnet kdc01.cube.k8s 88
```

### "Clock skew too great"

Synchronize time on all systems:

```bash
sudo timedatectl set-ntp true
date
```

### "Principal does not exist"

Create the principal:

```bash
kadmin.local -q "addprinc username@CUBE.K8S"
```

## Next Steps

- Read the full guide: `docs/kdc-setup-guide.md`
- Learn about mounting shares: `docs/user-management-and-mounting.md`
- Configure your file server: `group_vars/fileservers.yml`

## Security Reminders

✅ Use strong, random passwords  
✅ Encrypt sensitive variables with ansible-vault  
✅ Configure firewall to restrict KDC access  
✅ Ensure time synchronization (NTP)  
✅ Regular backups of Kerberos database  

## Quick Reference

```bash
# Get ticket
kinit username@REALM

# List tickets
klist

# Destroy ticket
kdestroy

# Admin console
kadmin.local

# List principals
kadmin.local -q "listprincs"

# View keytab
klist -k /path/to/keytab
```

---

**Need help?** Check `docs/kdc-setup-guide.md` for detailed documentation.
