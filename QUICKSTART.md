# Quick Start Guide - All-in-One File Server

Deploy a complete Kerberos-authenticated file server in minutes!

## 🚀 One-Command Deployment

```bash
./scripts/deploy-all-in-one.sh
```

That's it! This deploys both KDC and file server on a single host.

## 📋 Prerequisites

- One Debian/Ubuntu server
- Ansible installed on your machine
- SSH access to the server

## ⚙️ Configuration (Before Deployment)

### 1. Edit Inventory

`inventory/hosts.yml`:
```yaml
all:
  children:
    kdc:
      hosts:
        fileserver01:
          ansible_host: YOUR_SERVER_IP  # ← Change this
```

### 2. Edit KDC Variables

`group_vars/kdc.yml`:
```yaml
kdc_realm: "CUBE.K8S"                    # Your realm
kdc_master_password: "CHANGE_ME"         # Strong password!
kdc_admin_password: "CHANGE_ME"          # Strong password!
```

### 3. Edit File Server Variables

`group_vars/fileservers.yml`:
```yaml
krb5_realm: "CUBE.K8S"                   # Match KDC realm
samba_local_kdc: true                    # Important!
```

### 4. Encrypt Passwords

```bash
ansible-vault encrypt group_vars/kdc.yml
```

## 🎯 Deploy

```bash
./scripts/deploy-all-in-one.sh
```

## ✅ Verify

```bash
# SSH to server
ssh root@YOUR_SERVER

# Check services
systemctl status krb5-kdc smbd

# Test Kerberos
kinit admin/admin@CUBE.K8S
klist
```

## 👥 Create Users

```bash
# On the server
kadmin.local -q "addprinc alice@CUBE.K8S"
useradd -m -g users alice
```

## 💾 Mount Shares (From Client)

```bash
# Configure client
sudo vim /etc/krb5.conf
# Add your realm and KDC info

# Get ticket
kinit alice@CUBE.K8S

# Mount
sudo mount -t cifs //YOUR_SERVER/socialpro /mnt/share \
    -o sec=krb5,user=alice
```

## 📚 Documentation

- **Complete Guide:** [docs/all-in-one-setup.md](docs/all-in-one-setup.md)
- **User Management:** [docs/user-management-and-mounting.md](docs/user-management-and-mounting.md)
- **Architecture:** [docs/all-in-one-architecture.txt](docs/all-in-one-architecture.txt)

## 🆘 Troubleshooting

### Services won't start
```bash
systemctl status krb5-kdc smbd
journalctl -xe
```

### Can't get Kerberos ticket
```bash
# Check KDC is running
systemctl status krb5-kdc

# Check time sync
date  # Must be within 5 minutes of KDC
```

### Can't mount share
```bash
# Verify ticket
klist

# Test connectivity
telnet YOUR_SERVER 445
```

## 🔑 Quick Commands

```bash
# Create user
kadmin.local -q "addprinc user@REALM"
useradd -m -g users user

# List principals
kadmin.local -q "listprincs"

# View keytab
klist -k /etc/krb5.keytab

# Check logs
tail -f /var/log/krb5kdc.log
tail -f /var/log/samba/log.*
```

## 🎉 What You Get

✅ Kerberos KDC (authentication server)  
✅ Samba file server (SMB/CIFS)  
✅ NFS file server  
✅ Automatic keytab management  
✅ Secure, encrypted authentication  
✅ Ready for production use  

---

**Need help?** Check [docs/all-in-one-setup.md](docs/all-in-one-setup.md) for detailed instructions.
