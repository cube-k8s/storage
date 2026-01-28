# KDC Setup Guide

Complete guide for deploying and managing the Kerberos KDC.

## Deployment

### Configuration

Edit `group_vars/kdc.yml`:

```yaml
kdc_realm: "CUBE.K8S"
kdc_domain: "cube.k8s"
kdc_master_password: "StrongMasterPassword"
kdc_admin_password: "StrongAdminPassword"

# Service principals (auto-created)
kdc_service_principals:
  - "nfs/file-server.cube.k8s@CUBE.K8S"
  - "cifs/file-server.cube.k8s@CUBE.K8S"

# User principals (optional)
kdc_user_principals:
  - name: "alice"
    password: "alice123"
```

Encrypt sensitive data:
```bash
ansible-vault encrypt group_vars/kdc.yml
```

### Deploy

```bash
ansible-playbook playbooks/kdc.yml --ask-vault-pass
```

### Verify

```bash
ssh root@file-server.cube.k8s

# Check services
systemctl status krb5-kdc krb5-admin-server

# Test authentication
kinit admin/admin@CUBE.K8S
klist
```

## Managing Principals

### Using kadmin.local

```bash
# On KDC server
kadmin.local

# List all principals
listprincs

# Add user
addprinc alice@CUBE.K8S

# Add service (random key)
addprinc -randkey nfs/server.cube.k8s@CUBE.K8S

# Change password
cpw alice@CUBE.K8S

# Delete principal
delprinc alice@CUBE.K8S

# View details
getprinc alice@CUBE.K8S

quit
```

### Creating Keytabs

```bash
kadmin.local

# Export to keytab
ktadd -k /tmp/server.keytab nfs/server.cube.k8s@CUBE.K8S
ktadd -k /tmp/server.keytab cifs/server.cube.k8s@CUBE.K8S

quit

# Verify keytab
klist -k /tmp/server.keytab

# Set permissions
chmod 600 /tmp/server.keytab
```

### Creating System Users

Users need to exist both in Kerberos and as system users:

```bash
# On file server
groupadd users
useradd -m -g users alice
useradd -m -g users bob
```

## Configuration Files

### /etc/krb5.conf

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

### /etc/krb5kdc/kdc.conf

```ini
[kdcdefaults]
    kdc_ports = 88
    kdc_tcp_ports = 88

[realms]
    CUBE.K8S = {
        database_name = /var/lib/krb5kdc/principal
        admin_keytab = FILE:/etc/krb5kdc/kadm5.keytab
        acl_file = /etc/krb5kdc/kadm5.acl
        key_stash_file = /etc/krb5kdc/stash
        max_life = 24h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        supported_enctypes = aes256-cts-hmac-sha1-96:normal aes128-cts-hmac-sha1-96:normal
    }
```

## Backup and Recovery

### Backup

```bash
# Backup database
kdb5_util dump /backup/krb5-$(date +%Y%m%d).dump

# Backup config
tar -czf /backup/krb5-config-$(date +%Y%m%d).tar.gz \
    /etc/krb5kdc /etc/krb5.conf /etc/krb5.keytab
```

### Restore

```bash
systemctl stop krb5-kdc krb5-admin-server
kdb5_util load /backup/krb5-20260128.dump
systemctl start krb5-kdc krb5-admin-server
```

## Firewall

```bash
sudo ufw allow 88/tcp
sudo ufw allow 88/udp
sudo ufw allow 464/tcp
sudo ufw allow 464/udp
sudo ufw allow 749/tcp
```

## Troubleshooting

### "Cannot contact any KDC"

```bash
# Check KDC is running
systemctl status krb5-kdc
ss -tulpn | grep :88

# Test connectivity from client
telnet file-server.cube.k8s 88
```

### "Clock skew too great"

```bash
# Sync time (must be < 5 min difference)
sudo timedatectl set-ntp true
date
```

### "Principal does not exist"

```bash
kadmin.local -q "listprincs"
kadmin.local -q "addprinc user@CUBE.K8S"
```

### Debug Logging

```bash
# Enable detailed logging
tail -f /var/log/krb5kdc.log
```

## Quick Reference

```bash
kinit user@REALM          # Get ticket
klist                     # List tickets
kdestroy                  # Destroy tickets
klist -k /path/keytab     # View keytab

kadmin.local -q "listprincs"
kadmin.local -q "addprinc user@REALM"
kadmin.local -q "ktadd -k file.keytab principal@REALM"
```
