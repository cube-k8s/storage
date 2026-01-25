# Home Lab File Server - Ansible Deployment

This Ansible project deploys a Kerberos-authenticated file server with SMB (Samba) and NFS support on Debian systems. It includes optional MIT Kerberos KDC deployment for complete authentication infrastructure.

**🚀 Quick Start:** See [QUICKSTART.md](QUICKSTART.md) for one-command deployment!

## Project Structure

```
.
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml           # Inventory file with file server hosts
├── playbooks/
│   └── site.yml            # Main playbook
├── roles/                  # Ansible roles (created in subsequent tasks)
├── group_vars/
│   └── fileservers.yml     # Variables for fileservers group
├── host_vars/
│   └── fileserver01.yml    # Host-specific variables
└── templates/              # Jinja2 templates (created in subsequent tasks)
```

## Prerequisites

- Ansible 2.9 or higher installed on the controller
- Debian 11 or higher on target file server
- SSH access to target server with sudo privileges
- Kerberos KDC available (MIT Kerberos or Active Directory)
  - **Option 1:** Use the included KDC role to deploy MIT Kerberos (see [KDC Setup](#kerberos-kdc-setup))
  - **Option 2:** Use existing Kerberos infrastructure

## Quick Start

### Option A: All-in-One (Recommended for Home Labs)

Deploy both KDC and file server on a single host:

```bash
# 1. Configure settings
vim group_vars/kdc.yml
vim group_vars/fileservers.yml

# 2. Encrypt sensitive data
ansible-vault encrypt group_vars/kdc.yml

# 3. Deploy everything
./scripts/deploy-all-in-one.sh
```

See [All-in-One Setup Guide](docs/all-in-one-setup.md) for details.

### Option B: Deploy Everything (Separate KDC + File Server)

1. **Deploy Kerberos KDC** (if you don't have one):
   ```bash
   # Configure KDC settings
   vim group_vars/kdc.yml
   
   # Deploy KDC
   ./scripts/deploy-kdc.sh
   ```
   
   See [KDC Quick Start](docs/kdc-quick-start.md) for details.

2. **Deploy File Server**:
   ```bash
   # Configure file server settings
   vim group_vars/fileservers.yml
   
   # Deploy file server
   ansible-playbook playbooks/site.yml
   ```

### Option C: Deploy File Server Only (Existing KDC)

1. Update inventory file with your file server details:
   ```bash
   vim inventory/hosts.yml
   ```

2. Configure variables for your environment:
   ```bash
   vim group_vars/fileservers.yml
   ```

3. Run the playbook:
   ```bash
   ansible-playbook playbooks/site.yml
   ```

## Configuration

### Kerberos Settings

Edit `group_vars/fileservers.yml` to configure Kerberos:

- `krb5_realm`: Your Kerberos realm (e.g., HOMELAB.LOCAL)
- `krb5_kdc`: KDC server address
- `krb5_admin_server`: Kadmin server address

### Shares

Define shares in `group_vars/fileservers.yml`:

```yaml
shares:
  - path: "/srv/shares/myshare"
    owner: "root"
    group: "users"
    mode: "0775"
```

### Samba Configuration

Configure SMB shares in `samba_shares` variable.

### NFS Configuration

Configure NFS exports in `nfs_exports` variable.

## Usage

### Deploy Kerberos KDC

```bash
# Quick deployment
./scripts/deploy-kdc.sh

# Or manually
ansible-playbook playbooks/kdc.yml --ask-vault-pass
```

### Deploy File Server

Run the complete deployment:
```bash
ansible-playbook playbooks/site.yml
```

Check syntax:
```bash
ansible-playbook playbooks/site.yml --syntax-check
```

Dry run:
```bash
ansible-playbook playbooks/site.yml --check
```

### Mount SMB Shares

See [User Management and Mounting Guide](docs/user-management-and-mounting.md) for detailed instructions.

Quick example:
```bash
# Get Kerberos ticket
kinit username@CUBE.K8S

# Mount share
sudo mount -t cifs //fileserver01.cube.k8s/socialpro /mnt/socialpro \
    -o sec=krb5,user=username
```

## Kerberos KDC Setup

This project includes a complete MIT Kerberos KDC deployment role.

### Quick KDC Deployment

1. Configure `group_vars/kdc.yml`:
   ```yaml
   kdc_realm: "CUBE.K8S"
   kdc_domain: "cube.k8s"
   kdc_master_password: "YourStrongPassword"
   kdc_admin_password: "YourStrongPassword"
   ```

2. Encrypt sensitive data:
   ```bash
   ansible-vault encrypt group_vars/kdc.yml
   ```

3. Deploy:
   ```bash
   ./scripts/deploy-kdc.sh
   ```

### Documentation

- **All-in-One Setup:** [docs/all-in-one-setup.md](docs/all-in-one-setup.md) ⭐ Recommended for home labs
- **Quick Start:** [docs/kdc-quick-start.md](docs/kdc-quick-start.md)
- **Complete Guide:** [docs/kdc-setup-guide.md](docs/kdc-setup-guide.md)
- **User Management:** [docs/user-management-and-mounting.md](docs/user-management-and-mounting.md)
- **Architecture:** [docs/architecture-diagram.md](docs/architecture-diagram.md)

## Roles

### Implemented Roles

- **common:** Base system configuration
- **kerberos-client:** Kerberos client setup and keytab management
- **kerberos-kdc:** MIT Kerberos KDC deployment (optional)
- **shares:** Share directory management
- **samba:** SMB file sharing with Kerberos authentication
- **nfs-server:** NFS file sharing (to be implemented)

### Role Documentation

Each role includes detailed documentation in its README:
- [kerberos-kdc](roles/kerberos-kdc/README.md)

## Next Steps

The roles will be implemented in subsequent tasks:
- common: Base system configuration ✅
- kerberos-client: Kerberos client setup ✅
- kerberos-kdc: MIT Kerberos KDC deployment ✅
- shares: Share directory management ✅
- samba: SMB file sharing ✅
- nfs-server: NFS file sharing (in progress)
