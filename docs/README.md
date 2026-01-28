# File Server Documentation

Ansible-based file server with Kerberos authentication for NFS and SMB shares.

## Quick Links

| Document | Description |
|----------|-------------|
| [Quick Start](QUICKSTART.md) | Get started in 5 minutes |
| [Architecture](architecture.md) | System architecture diagrams |
| [KDC Setup](kdc-setup.md) | Kerberos KDC configuration |
| [Client Setup](client-setup.md) | Linux/macOS client mounting |
| [Kubernetes](kubernetes-nfs.md) | NFS in Kubernetes pods |
| [Permissions](permissions.md) | NFS permissions guide |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |

## Overview

This project deploys:
- **Kerberos KDC** - Centralized authentication
- **NFS Server** - NFSv4 with Kerberos security (krb5/krb5i/krb5p)
- **Samba Server** - SMB shares with Kerberos authentication

## Architecture

```
┌─────────────────────────────────────────┐
│  File Server (file-server.cube.k8s)     │
│  ┌─────────────┐  ┌─────────────────┐  │
│  │ Kerberos KDC│  │ NFS + Samba     │  │
│  │ Port 88     │  │ Ports 2049, 445 │  │
│  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────┘
           ▲
           │ Kerberos Auth
           │
    ┌──────┴──────┐
    │   Clients   │
    └─────────────┘
```

## Deployment

```bash
# Deploy everything (KDC + file server)
./scripts/deploy-all-in-one.sh

# Or step by step
ansible-playbook playbooks/kdc.yml --ask-vault-pass
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## Quick Test

```bash
# Get Kerberos ticket
kinit gustavo@CUBE.K8S

# Mount NFS
sudo mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/socialpro /mnt/test

# Verify
ls -la /mnt/test
```

## Security

All shares require Kerberos authentication:
- `sec=krb5` - Authentication only
- `sec=krb5i` - Authentication + integrity
- `sec=krb5p` - Authentication + encryption (recommended)

## Current Shares

| Share | Path | Description |
|-------|------|-------------|
| socialpro | `/srv/shares/socialpro` | SocialPRO files |
| photos-vol | `/srv/shares/photos-vol` | Photos volume |
| photos-lib | `/srv/shares/photos-lib` | Photos library |

## User Credentials

| User | Realm | Notes |
|------|-------|-------|
| gustavo | CUBE.K8S | Primary user |
| admin/admin | CUBE.K8S | Admin principal |
