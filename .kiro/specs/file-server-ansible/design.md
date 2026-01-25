# Design Document: Home Lab File Server

## Overview

This design describes a home lab file server implementation that provides both SMB (via Samba) and NFS file sharing with Kerberos authentication. The entire infrastructure is deployed and managed using Ansible playbooks targeting Debian Linux systems.

The design follows an infrastructure-as-code approach where all configuration is defined in Ansible variables and templates, enabling reproducible deployments and version-controlled configuration management.

### Key Design Decisions

1. **Debian as Target OS**: Using Debian provides stability, long-term support, and well-maintained packages for Samba, NFS, and Kerberos
2. **Kerberos for Authentication**: Eliminates plaintext credential transmission and provides centralized authentication
3. **Ansible for Deployment**: Enables declarative configuration, idempotency, and infrastructure as code
4. **Dual Protocol Support**: SMB for Windows/mixed clients, NFS for Linux/Unix clients
5. **Service Principal Management**: Automated creation and management of Kerberos service principals and keytabs

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Ansible Controller                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Playbooks   │  │  Variables   │  │  Templates   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└────────────────────────┬────────────────────────────────────┘
                         │ SSH + Ansible
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  File Server (Debian)                        │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Kerberos Client (krb5)                  │   │
│  │  - krb5.conf configuration                           │   │
│  │  - Service keytabs                                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                         │                                    │
│         ┌───────────────┴───────────────┐                   │
│         ▼                               ▼                   │
│  ┌─────────────┐                 ┌─────────────┐           │
│  │   Samba     │                 │     NFS     │           │
│  │  (smbd)     │                 │  (nfs-server)│          │
│  │             │                 │             │           │
│  │ - smb.conf  │                 │ - exports   │           │
│  │ - Kerberos  │                 │ - sec=krb5* │           │
│  │   auth      │                 │             │           │
│  └─────────────┘                 └─────────────┘           │
│         │                               │                   │
│         └───────────────┬───────────────┘                   │
│                         ▼                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Shared Storage                          │   │
│  │  /srv/shares/share1                                  │   │
│  │  /srv/shares/share2                                  │   │
│  │  ...                                                 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                         ▲
                         │ SMB/NFS + Kerberos
                         │
┌────────────────────────┴────────────────────────────────────┐
│              MIT Kerberos KDC (Separate Host)                │
│  - User principals (user@REALM)                              │
│  - Service principals (nfs/host@REALM, cifs/host@REALM)     │
│  - Ticket granting service                                   │
│  - kadmin for principal management                           │
│                                                               │
│  Note: Can be deployed with Ansible or manually configured   │
└─────────────────────────────────────────────────────────────┘
                         ▲
                         │ Kerberos auth
                         │
                  ┌──────┴──────┐
                  │   Clients   │
                  │ (Windows,   │
                  │  Linux)     │
                  └─────────────┘
```

### Component Interactions

1. **Ansible Controller → File Server**: Deploys configuration, installs packages, manages services
2. **File Server → Kerberos KDC**: Authenticates service principals, validates client tickets
3. **Clients → Kerberos KDC**: Obtain user tickets and service tickets
4. **Clients → File Server**: Access shares using Kerberos-authenticated SMB or NFS

### Kerberos Infrastructure Options

This design supports two Kerberos infrastructure approaches:

**Option 1: MIT Kerberos KDC (Recommended for Home Lab)**
- Standalone Kerberos server (no Active Directory required)
- Lightweight and simple to set up
- Can be deployed on a separate VM or even the same host
- Provides pure Kerberos authentication without Windows domain features
- Ansible can optionally deploy and configure the KDC

**Option 2: Active Directory Domain Controller**
- Use existing Windows Active Directory (AD includes Kerberos KDC)
- File server joins AD domain
- Samba configured with `security = ads` mode
- Useful if you already have AD infrastructure

**For this design, we'll focus on Option 1 (MIT Kerberos)** as it's simpler and doesn't require Windows infrastructure. The design can be adapted for AD by changing Samba security mode and domain join procedures.

### Network Requirements

- File server must have network connectivity to Kerberos KDC
- Clients must have network connectivity to both KDC and file server
- Required ports:
  - SMB: 445/tcp (SMB over TCP)
  - NFS: 2049/tcp (NFSv4)
  - Kerberos: 88/tcp, 88/udp (KDC)
  - Kerberos: 464/tcp, 464/udp (kadmin, for principal management)

## Components and Interfaces

### Ansible Playbook Structure

```
file-server-ansible/
├── playbooks/
│   ├── site.yml                    # Main playbook
│   ├── fileserver.yml              # File server configuration
│   └── kerberos-setup.yml          # Kerberos integration
├── roles/
│   ├── common/                     # Base system configuration
│   ├── kerberos-client/            # Kerberos client setup
│   ├── samba/                      # Samba configuration
│   ├── nfs-server/                 # NFS server configuration
│   └── shares/                     # Share creation and permissions
├── group_vars/
│   └── fileservers.yml             # File server variables
├── host_vars/
│   └── fileserver01.yml            # Host-specific variables
├── templates/
│   ├── krb5.conf.j2                # Kerberos client config
│   ├── smb.conf.j2                 # Samba config
│   └── exports.j2                  # NFS exports
└── inventory/
    └── hosts.yml                   # Inventory file
```

### Role: common

**Purpose**: Base system configuration and package installation

**Tasks**:
- Update apt cache
- Install base packages (python3, acl, attr)
- Configure timezone and locale
- Set hostname

**Variables**:
- `base_packages`: List of base packages to install

### Role: kerberos-client

**Purpose**: Configure Kerberos client integration

**Tasks**:
- Install Kerberos client packages (krb5-user, libpam-krb5)
- Template krb5.conf with realm and KDC information
- Create service principals (if KDC access provided)
- Generate and install keytabs for services
- Validate Kerberos configuration

**Variables**:
- `krb5_realm`: Kerberos realm (e.g., HOMELAB.LOCAL)
- `krb5_kdc`: KDC server address
- `krb5_admin_server`: Kadmin server address (optional)
- `krb5_service_principals`: List of service principals to create
- `krb5_kadmin_principal`: Admin principal for KDC operations (e.g., admin/admin@REALM)
- `krb5_kadmin_password`: Admin password (should be vaulted)

**Templates**:
- `krb5.conf.j2`: Kerberos client configuration

**Keytab Management**:
- Service keytabs stored in `/etc/krb5.keytab` (default) or service-specific locations
- Keytabs must be readable by service users (root for NFS, samba user for Samba)
- Ansible can create principals and export keytabs if kadmin credentials provided
- Alternatively, keytabs can be pre-created and copied to the file server

**KDC Deployment Options**:

The playbooks support three KDC scenarios:

1. **Existing KDC with kadmin access**: Ansible creates principals and exports keytabs automatically
   - Requires: `krb5_kadmin_principal` and `krb5_kadmin_password` variables
   - Ansible uses `kadmin` command to create principals and export keytabs

2. **Existing KDC without kadmin access**: Manually create principals and provide keytabs
   - Create principals: `kadmin.local -q "addprinc -randkey nfs/fileserver.homelab.local"`
   - Export keytabs: `kadmin.local -q "ktadd -k /tmp/fileserver.keytab nfs/fileserver.homelab.local"`
   - Copy keytab to file server and specify path in variables

3. **No existing KDC**: Optionally deploy MIT Kerberos KDC using Ansible
   - Separate playbook/role can deploy KDC on another host
   - Then use option 1 or 2 above for file server integration

### Role: samba

**Purpose**: Install and configure Samba with Kerberos authentication

**Tasks**:
- Install Samba packages (samba, samba-common-bin, winbind)
- Template smb.conf with Kerberos settings
- Configure Samba to use Kerberos (security = ads or security = user with Kerberos)
- Set up service principal (cifs/hostname.realm)
- Enable and start smbd, nmbd, winbind services
- Configure firewall rules for SMB

**Variables**:
- `samba_workgroup`: Workgroup name
- `samba_realm`: Kerberos realm
- `samba_security`: Security mode (ads or user)
- `samba_shares`: List of share definitions

**Templates**:
- `smb.conf.j2`: Samba configuration with Kerberos auth

**Share Definition Structure**:
```yaml
samba_shares:
  - name: public
    path: /srv/shares/public
    comment: "Public share"
    read_only: no
    valid_users: "@users"
  - name: private
    path: /srv/shares/private
    comment: "Private share"
    read_only: no
    valid_users: "admin"
```

### Role: nfs-server

**Purpose**: Install and configure NFS server with Kerberos authentication

**Tasks**:
- Install NFS server packages (nfs-kernel-server, nfs-common)
- Configure NFS to use Kerberos (NEED_GSSD=yes, NEED_SVCGSSD=yes)
- Template /etc/exports with sec=krb5* options
- Set up service principal (nfs/hostname.realm)
- Enable and start nfs-server, rpc-gssd, rpc-svcgssd services
- Configure firewall rules for NFS

**Variables**:
- `nfs_exports`: List of export definitions

**Templates**:
- `exports.j2`: NFS exports configuration

**Export Definition Structure**:
```yaml
nfs_exports:
  - path: /srv/shares/public
    clients:
      - host: "*.homelab.local"
        options: "rw,sync,sec=krb5:krb5i:krb5p,no_subtree_check"
  - path: /srv/shares/private
    clients:
      - host: "trusted-host.homelab.local"
        options: "rw,sync,sec=krb5p,no_subtree_check"
```

**Kerberos Security Levels**:
- `sec=krb5`: Kerberos authentication only
- `sec=krb5i`: Kerberos authentication + integrity checking
- `sec=krb5p`: Kerberos authentication + privacy (encryption)

### Role: shares

**Purpose**: Create and manage shared directories

**Tasks**:
- Create share directories with proper ownership
- Set filesystem permissions and ACLs
- Create directory structure
- Validate share paths exist and are accessible

**Variables**:
- `shares`: Unified list of share definitions with paths, owners, groups, permissions

**Share Structure**:
```yaml
shares:
  - path: /srv/shares/public
    owner: root
    group: users
    mode: "0775"
  - path: /srv/shares/private
    owner: admin
    group: admin
    mode: "0770"
```

## Data Models

### Ansible Variables Schema

#### Kerberos Configuration

```yaml
# Kerberos realm and KDC settings
krb5_realm: "HOMELAB.LOCAL"
krb5_kdc: "kdc.homelab.local"
krb5_admin_server: "kdc.homelab.local"

# Service principals to create
krb5_service_principals:
  - "nfs/{{ ansible_fqdn }}@{{ krb5_realm }}"
  - "cifs/{{ ansible_fqdn }}@{{ krb5_realm }}"

# Keytab paths
krb5_keytab_path: "/etc/krb5.keytab"
```

#### Samba Configuration

```yaml
# Samba global settings
samba_workgroup: "HOMELAB"
samba_realm: "{{ krb5_realm }}"
samba_security: "user"  # or "ads" for Active Directory
samba_kerberos_method: "secrets and keytab"

# Samba shares
samba_shares:
  - name: "public"
    path: "/srv/shares/public"
    comment: "Public file share"
    read_only: no
    browseable: yes
    valid_users: "@users"
    create_mask: "0664"
    directory_mask: "0775"
  
  - name: "private"
    path: "/srv/shares/private"
    comment: "Private file share"
    read_only: no
    browseable: no
    valid_users: "admin"
    create_mask: "0660"
    directory_mask: "0770"
```

#### NFS Configuration

```yaml
# NFS exports
nfs_exports:
  - path: "/srv/shares/public"
    clients:
      - host: "*.homelab.local"
        options: "rw,sync,sec=krb5:krb5i:krb5p,no_subtree_check,fsid=1"
      - host: "192.168.1.0/24"
        options: "rw,sync,sec=krb5:krb5i:krb5p,no_subtree_check,fsid=1"
  
  - path: "/srv/shares/private"
    clients:
      - host: "trusted-host.homelab.local"
        options: "rw,sync,sec=krb5p,no_subtree_check,fsid=2"
```

#### Share Management

```yaml
# Unified share definitions
shares:
  - path: "/srv/shares/public"
    owner: "root"
    group: "users"
    mode: "0775"
    description: "Public shared storage"
  
  - path: "/srv/shares/private"
    owner: "admin"
    group: "admin"
    mode: "0770"
    description: "Private administrative storage"
```

### Configuration File Templates

#### krb5.conf Template

```ini
[libdefaults]
    default_realm = {{ krb5_realm }}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false

[realms]
    {{ krb5_realm }} = {
        kdc = {{ krb5_kdc }}
        admin_server = {{ krb5_admin_server | default(krb5_kdc) }}
    }

[domain_realm]
    .{{ krb5_realm | lower }} = {{ krb5_realm }}
    {{ krb5_realm | lower }} = {{ krb5_realm }}
```

#### smb.conf Template (Key Sections)

```ini
[global]
    workgroup = {{ samba_workgroup }}
    realm = {{ samba_realm }}
    security = {{ samba_security }}
    kerberos method = {{ samba_kerberos_method }}
    
    # Kerberos settings
    dedicated keytab file = {{ krb5_keytab_path }}
    
    # Logging
    log file = /var/log/samba/log.%m
    max log size = 1000
    log level = 3 auth:5 winbind:5

{% for share in samba_shares %}
[{{ share.name }}]
    path = {{ share.path }}
    comment = {{ share.comment | default('') }}
    read only = {{ share.read_only | default('no') }}
    browseable = {{ share.browseable | default('yes') }}
    valid users = {{ share.valid_users | default('') }}
    create mask = {{ share.create_mask | default('0664') }}
    directory mask = {{ share.directory_mask | default('0775') }}
{% endfor %}
```

#### exports Template

```
# /etc/exports - NFS exports configuration
{% for export in nfs_exports %}
{% for client in export.clients %}
{{ export.path }} {{ client.host }}({{ client.options }})
{% endfor %}
{% endfor %}
```


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property 1: Kerberos Authentication Enforcement

*For any* client connection attempt to either SMB or NFS shares, the file server should require and validate Kerberos authentication, rejecting connections that do not present valid Kerberos tickets.

**Validates: Requirements 1.2, 2.2**

### Property 2: Permission-Based Access Control

*For any* authenticated Kerberos principal and any share (SMB or NFS), access should be granted if and only if the principal's identity matches the configured access control rules for that share.

**Validates: Requirements 1.3, 2.3, 6.1, 6.2**

### Property 3: Share Enumeration Matches Permissions

*For any* authenticated user requesting a share listing via SMB, the returned list should contain exactly those shares for which the user has access permissions—no more, no less.

**Validates: Requirements 1.5**

### Property 4: Ansible Idempotency

*For any* Ansible playbook execution on a system where the playbook has already been run, the second execution should report zero changes and leave the system in an identical state.

**Validates: Requirements 4.6, 5.5**

### Property 5: Package Installation Completeness

*For any* package listed in the required packages variables, after Ansible playbook execution, that package should be installed and at the specified version (if version is specified).

**Validates: Requirements 4.2**

### Property 6: Configuration Variable Propagation

*For any* configuration variable change in Ansible variables, after playbook execution, the corresponding configuration file on the file server should reflect the new value.

**Validates: Requirements 8.2, 4.7**

### Property 7: Share Directory Creation and Permissions

*For any* share defined in the configuration with specified path, owner, group, and mode, after Ansible playbook execution, the directory should exist with exactly those ownership and permission attributes.

**Validates: Requirements 5.2, 5.4**

### Property 8: Configurable Storage Paths

*For any* valid filesystem path specified in share configuration, the Ansible playbook should successfully create and configure a share at that path.

**Validates: Requirements 5.1**

### Property 9: Service Restart on Configuration Change

*For any* configuration file change that affects a service (Samba or NFS), after Ansible playbook execution, the affected service should be reloaded or restarted to apply the new configuration.

**Validates: Requirements 7.5**

### Property 10: Authentication Logging Completeness

*For any* authentication attempt (successful or failed) to either SMB or NFS, the file server logs should contain an entry with timestamp, principal name, and authentication result.

**Validates: Requirements 9.1, 9.5**

### Property 11: Access Logging Completeness

*For any* successful share access via SMB or NFS, the file server logs should contain an entry with timestamp, principal name, and share name.

**Validates: Requirements 9.2**

### Property 12: Access Denial Logging

*For any* denied access attempt to a share, the file server logs should contain an entry with timestamp, principal name, share name, and denial reason.

**Validates: Requirements 6.5**

### Property 13: Configuration Validation

*For any* invalid configuration value (e.g., malformed Kerberos realm, invalid file path, syntax error), the Ansible playbook should detect the error and halt execution before applying changes.

**Validates: Requirements 8.4, 8.5**

## Error Handling

### Kerberos Authentication Failures

**Scenario**: Client attempts to connect without valid Kerberos ticket

**Handling**:
- SMB: Return authentication error, log failure with principal (if available) or "anonymous"
- NFS: Refuse mount, return "access denied" error
- Both: Log detailed error including reason (no ticket, expired ticket, wrong realm, etc.)

**Recovery**: Client must obtain valid Kerberos ticket (kinit) and retry

### Service Principal or Keytab Issues

**Scenario**: Service keytab is missing, expired, or contains wrong principals

**Handling**:
- Service startup should fail with clear error message
- Log error indicating keytab problem
- Prevent service from starting in degraded mode without authentication

**Recovery**: 
- Re-run Ansible playbook to regenerate keytabs
- Manually create principals and export keytabs if KDC access is unavailable

### KDC Unavailability

**Scenario**: Kerberos KDC is unreachable

**Handling**:
- Existing authenticated connections continue to work until ticket expiration
- New authentication attempts fail with "KDC unreachable" error
- Services log KDC connectivity issues

**Recovery**:
- Restore KDC connectivity
- Clients may need to renew tickets once KDC is available

### Storage Issues

**Scenario**: Share directory is missing, has wrong permissions, or filesystem is full

**Handling**:
- Ansible playbook should detect missing directories and create them
- Ansible playbook should correct wrong permissions
- Full filesystem: Services log errors, clients receive "no space" errors

**Recovery**:
- Re-run Ansible playbook to fix directory/permission issues
- Free up space or expand filesystem for full disk issues

### Configuration Errors

**Scenario**: Invalid configuration in Ansible variables (e.g., malformed realm name, invalid path)

**Handling**:
- Ansible playbook should validate configuration before applying
- Use assert tasks to check critical values
- Fail fast with descriptive error messages

**Recovery**:
- Fix configuration in Ansible variables
- Re-run playbook

### Network Issues

**Scenario**: Network connectivity problems between components

**Handling**:
- File server logs connection failures
- Clients receive timeout or connection refused errors
- Services continue running, waiting for connectivity restoration

**Recovery**:
- Restore network connectivity
- Clients automatically retry connections

### Service Crashes

**Scenario**: Samba or NFS service crashes unexpectedly

**Handling**:
- Systemd automatically restarts service (configured with Restart=on-failure)
- Service logs crash information
- Ansible configures restart limits to prevent restart loops

**Recovery**:
- Automatic via systemd restart
- If restart fails repeatedly, investigate logs and fix underlying issue

## Testing Strategy

### Dual Testing Approach

This feature requires both unit tests and property-based tests for comprehensive validation:

- **Unit tests**: Verify specific examples, edge cases, and error conditions
- **Property tests**: Verify universal properties across all inputs using randomized testing

Both testing approaches are complementary and necessary. Unit tests catch concrete bugs in specific scenarios, while property tests verify general correctness across a wide range of inputs.

### Property-Based Testing

Property-based testing will be implemented using **Testinfra** for infrastructure testing combined with **pytest** for test execution. While Testinfra doesn't have built-in property-based testing, we'll use **Hypothesis** (Python property-based testing library) to generate test inputs.

**Configuration**:
- Minimum 100 iterations per property test (due to randomization)
- Each property test references its design document property
- Tag format: `# Feature: file-server-ansible, Property {number}: {property_text}`

**Property Test Implementation Approach**:

1. **Properties 1-3 (Authentication and Access Control)**: Generate random user principals and share configurations, verify authentication and authorization behavior
2. **Property 4 (Idempotency)**: Run Ansible playbook twice, verify second run makes no changes
3. **Properties 5-9 (Configuration Management)**: Generate random valid configuration values, verify they're correctly applied
4. **Properties 10-12 (Logging)**: Generate random access attempts, verify log entries exist with required fields
5. **Property 13 (Validation)**: Generate random invalid configurations, verify playbook rejects them

### Unit Testing

Unit tests will focus on:

**Ansible Playbook Testing**:
- Test individual roles in isolation using Molecule
- Verify task execution with specific variable values
- Test handlers trigger correctly
- Verify template rendering with known inputs

**Configuration Testing**:
- Test specific Kerberos realm configurations
- Test specific share configurations (read-only, read-write, specific users)
- Test service startup with valid keytabs
- Test service failure with invalid keytabs (edge case)

**Integration Testing**:
- Test complete deployment on fresh Debian system
- Test SMB client connection with Kerberos
- Test NFS client mount with sec=krb5, sec=krb5i, sec=krb5p
- Test access denial for unauthorized users
- Test log file creation and content

**Edge Cases**:
- Invalid keytab (Requirement 3.5)
- Empty share list
- Share path with special characters
- Very long principal names
- Concurrent access from multiple clients

### Test Environment

**Requirements**:
- Debian test VM or container
- Kerberos KDC (can be containerized MIT Kerberos)
- Test clients (Linux and Windows if possible)
- Ansible controller with test playbooks

**Test Infrastructure**:
- Use Molecule for Ansible role testing
- Use Docker or Vagrant for test VMs
- Use pytest for test execution
- Use Testinfra for infrastructure validation

### Testing Workflow

1. **Linting**: Ansible-lint for playbook syntax and best practices
2. **Unit Tests**: Molecule tests for individual roles
3. **Property Tests**: Hypothesis-based tests for configuration variations
4. **Integration Tests**: Full deployment tests with real Kerberos
5. **Manual Tests**: Client connectivity from Windows and Linux

### Continuous Testing

- Run linting and unit tests on every commit
- Run property tests on pull requests
- Run full integration tests before releases
- Maintain test environment for manual verification

