# Quick Start Guide

Get your file server running in 5 minutes.

## Prerequisites

- Debian/Ubuntu server with SSH access
- Ansible installed on control machine
- Static IP and FQDN for server

## Step 1: Configure Inventory

Edit `inventory/hosts.yml`:

```yaml
all:
  children:
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

## Step 2: Configure Variables

Edit `group_vars/kdc.yml`:

```yaml
kdc_realm: "CUBE.K8S"
kdc_domain: "cube.k8s"
kdc_master_password: "YourStrongPassword"
kdc_admin_password: "YourAdminPassword"
```

Encrypt sensitive data:
```bash
ansible-vault encrypt group_vars/kdc.yml
```

## Step 3: Deploy

```bash
./scripts/deploy-all-in-one.sh
# Or: ansible-playbook playbooks/all-in-one.yml --ask-vault-pass
```

## Step 4: Verify

```bash
ssh root@file-server.cube.k8s

# Check services
systemctl status krb5-kdc smbd nfs-server

# Test Kerberos
kinit admin/admin@CUBE.K8S
klist
```

## Step 5: Mount from Client

```bash
# Configure /etc/krb5.conf on client (see client-setup.md)

# Get ticket
kinit gustavo@CUBE.K8S

# Mount NFS
sudo mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/socialpro /mnt/test

# Mount SMB
sudo mount -t cifs -o sec=krb5 //file-server.cube.k8s/socialpro /mnt/test
```

## Common Commands

```bash
# Kerberos
kinit user@REALM      # Get ticket
klist                 # List tickets
kdestroy              # Destroy tickets

# Admin
kadmin.local -q "listprincs"           # List principals
kadmin.local -q "addprinc user@REALM"  # Add user

# Services
systemctl status krb5-kdc smbd nfs-server
```

## Next Steps

- [Client Setup](client-setup.md) - Configure client machines
- [Kubernetes](kubernetes-nfs.md) - Use with Kubernetes
- [Troubleshooting](troubleshooting.md) - Fix common issues
