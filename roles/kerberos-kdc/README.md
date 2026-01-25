# Kerberos KDC Role

Ansible role to deploy and configure a MIT Kerberos Key Distribution Center (KDC).

## Description

This role installs and configures a MIT Kerberos KDC on Debian/Ubuntu systems. It handles:

- Installation of KDC packages
- Database initialization
- Configuration of realm and encryption types
- Creation of admin principals
- Automatic creation of service and user principals
- **Automatic OS user creation for Kerberos principals**
- Keytab generation and export
- Service management

## Requirements

- Debian 11+ or Ubuntu 20.04+
- Root or sudo access
- Static IP address
- Fully qualified domain name (FQDN)
- Time synchronization (NTP)

## Role Variables

### Required Variables

```yaml
kdc_realm: "EXAMPLE.COM"              # Kerberos realm (uppercase)
kdc_domain: "example.com"             # DNS domain (lowercase)
kdc_master_password: "changeme"       # Database master password
kdc_admin_password: "changeme"        # Admin principal password
```

### Optional Variables

```yaml
# Admin principal name
kdc_admin_principal: "admin/admin"

# Ticket lifetimes
kdc_max_life: "24h 0m 0s"
kdc_max_renewable_life: "7d 0h 0m 0s"

# Encryption types
kdc_supported_enctypes:
  - "aes256-cts-hmac-sha1-96:normal"
  - "aes128-cts-hmac-sha1-96:normal"

# ACL entries
kdc_acl_entries:
  - principal: "*/admin@{{ kdc_realm }}"
    permissions: "*"

# Service principals to create
kdc_service_principals:
  - "nfs/fileserver.example.com@EXAMPLE.COM"
  - "cifs/fileserver.example.com@EXAMPLE.COM"

# User principals to create
kdc_user_principals:
  - name: "alice"
    password: "password123"
    comment: "Alice Smith"          # Optional: User description
    group: "users"                  # Optional: Primary group (default: users)
    groups: ["developers"]          # Optional: Additional groups
    shell: "/bin/bash"              # Optional: Login shell (default: /bin/bash)
    create_home: true               # Optional: Create home directory (default: true)
  - name: "bob"
    password: "password456"

# Create OS users for Kerberos principals
# When enabled, automatically creates Linux users matching Kerberos principals
kdc_create_os_users: true

# Keytab export directory
kdc_keytab_export_dir: "/var/lib/krb5kdc/keytabs"
```

## Dependencies

None.

## Example Playbook

```yaml
---
- name: Deploy Kerberos KDC
  hosts: kdc
  become: true
  
  roles:
    - role: kerberos-kdc
      kdc_realm: "HOMELAB.LOCAL"
      kdc_domain: "homelab.local"
      kdc_master_password: "{{ vault_kdc_master_password }}"
      kdc_admin_password: "{{ vault_kdc_admin_password }}"
      kdc_service_principals:
        - "nfs/fileserver.homelab.local@HOMELAB.LOCAL"
        - "cifs/fileserver.homelab.local@HOMELAB.LOCAL"
```

## Usage

### 1. Configure Variables

Create `group_vars/kdc.yml`:

```yaml
kdc_realm: "HOMELAB.LOCAL"
kdc_domain: "homelab.local"
kdc_master_password: "YourStrongPassword"
kdc_admin_password: "YourStrongPassword"
```

### 2. Encrypt Sensitive Data

```bash
ansible-vault encrypt group_vars/kdc.yml
```

### 3. Deploy

```bash
ansible-playbook playbooks/kdc.yml --ask-vault-pass
```

### 4. Verify

```bash
ssh root@kdc
kinit admin/admin@HOMELAB.LOCAL
klist
```

## Post-Installation

### Create Additional Principals

```bash
kadmin.local
addprinc username@REALM
addprinc -randkey service/host@REALM
quit
```

### Export Keytabs

```bash
kadmin.local
ktadd -k /tmp/service.keytab service/host@REALM
quit
```

### List Principals

```bash
kadmin.local -q "listprincs"
```

## Security Considerations

1. **Use strong passwords** for master and admin passwords
2. **Encrypt variables** with ansible-vault
3. **Restrict network access** to KDC ports (88, 464, 749)
4. **Synchronize time** across all systems (within 5 minutes)
5. **Regular backups** of Kerberos database
6. **Monitor logs** for suspicious activity

## Files Created

- `/etc/krb5.conf` - Kerberos client configuration
- `/etc/krb5kdc/kdc.conf` - KDC configuration
- `/etc/krb5kdc/kadm5.acl` - Admin ACL
- `/var/lib/krb5kdc/principal` - Kerberos database
- `/var/lib/krb5kdc/keytabs/` - Exported keytabs

## Tags

- `kdc` - All KDC tasks
- `packages` - Package installation
- `config` - Configuration tasks
- `database` - Database initialization
- `principals` - Principal creation
- `services` - Service management
- `keytabs` - Keytab export

## License

MIT

## Author

Generated for home lab file server project
