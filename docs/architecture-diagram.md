# File Server Architecture with Kerberos Authentication

## Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Ansible Controller                              │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│  │  playbooks/      │  │  roles/          │  │  group_vars/     │    │
│  │  - kdc.yml       │  │  - kerberos-kdc  │  │  - kdc.yml       │    │
│  │  - site.yml      │  │  - kerberos-     │  │  - fileservers.  │    │
│  │                  │  │    client        │  │    yml           │    │
│  │                  │  │  - samba         │  │                  │    │
│  │                  │  │  - nfs-server    │  │                  │    │
│  │                  │  │  - shares        │  │                  │    │
│  │                  │  │  - common        │  │                  │    │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘    │
│                                                                         │
└────────────┬────────────────────────────────────┬─────────────────────┘
             │ SSH + Ansible                      │ SSH + Ansible
             │                                    │
             ▼                                    ▼
┌─────────────────────────────────┐  ┌─────────────────────────────────┐
│   Kerberos KDC Server           │  │   File Server (Debian)          │
│   (kdc01.cube.k8s)              │  │   (fileserver01.cube.k8s)       │
│                                 │  │                                 │
│  ┌───────────────────────────┐ │  │  ┌───────────────────────────┐ │
│  │  MIT Kerberos KDC         │ │  │  │  Kerberos Client          │ │
│  │  - Port 88 (TCP/UDP)      │ │  │  │  - /etc/krb5.conf         │ │
│  │  - Port 464 (TCP/UDP)     │ │  │  │  - /etc/krb5.keytab       │ │
│  │  - Port 749 (TCP)         │ │  │  │  - Service principals:    │ │
│  │                           │ │  │  │    * nfs/fileserver01...  │ │
│  │  Database:                │ │  │  │    * cifs/fileserver01... │ │
│  │  - User principals        │ │  │  └───────────────────────────┘ │
│  │    * alice@CUBE.K8S       │ │  │              │                  │
│  │    * bob@CUBE.K8S         │ │  │              │                  │
│  │    * admin@CUBE.K8S       │ │  │    ┌─────────┴─────────┐       │
│  │  - Service principals     │ │  │    │                   │       │
│  │    * nfs/fileserver...    │ │  │    ▼                   ▼       │
│  │    * cifs/fileserver...   │ │  │  ┌──────────┐    ┌──────────┐ │
│  │  - Admin principals       │ │  │  │  Samba   │    │   NFS    │ │
│  │    * admin/admin@...      │ │  │  │  (smbd)  │    │  Server  │ │
│  │                           │ │  │  │          │    │          │ │
│  │  Keytabs exported to:     │ │  │  │ Port 445 │    │ Port     │ │
│  │  /var/lib/krb5kdc/keytabs/│ │  │  │          │    │ 2049     │ │
│  └───────────────────────────┘ │  │  │ Config:  │    │          │ │
│                                 │  │  │ - smb.   │    │ Config:  │ │
│  Configuration:                 │  │  │   conf   │    │ - /etc/  │ │
│  - /etc/krb5kdc/kdc.conf       │  │  │ - Kerb.  │    │   exports│ │
│  - /etc/krb5kdc/kadm5.acl     │  │  │   keytab │    │ - Kerb.  │ │
│  - /etc/krb5.conf              │  │  │ - Log:   │    │   keytab │ │
│                                 │  │  │   /var/  │    │ - sec=   │ │
│  Logs:                          │  │  │   log/   │    │   krb5*  │ │
│  - /var/log/krb5kdc.log        │  │  │   samba/ │    │          │ │
│  - /var/log/kadmin.log         │  │  └──────────┘    └──────────┘ │
│                                 │  │       │              │        │
└────────────┬────────────────────┘  └───────┼──────────────┼────────┘
             │                               │              │
             │ Kerberos Auth                 │              │
             │ (Ticket Granting)             │              │
             │                               │              │
             └───────────────┬───────────────┘              │
                             │                              │
                             │ SMB/CIFS + Kerberos          │ NFS + Kerberos
                             │ (sec=krb5/krb5i/krb5p)       │ (sec=krb5/krb5i/krb5p)
                             │                              │
                    ┌────────┴────────┬─────────────────────┘
                    │                 │
                    ▼                 ▼
        ┌─────────────────┐  ┌─────────────────┐
        │  Linux Client   │  │  Windows Client │
        │                 │  │                 │
        │  1. kinit user  │  │  1. kinit user  │
        │  2. mount -t    │  │  2. net use Z:  │
        │     cifs ...    │  │     \\server\   │
        │                 │  │     share       │
        │  /etc/krb5.conf │  │                 │
        │  points to KDC  │  │  krb5.ini       │
        │                 │  │  points to KDC  │
        └─────────────────┘  └─────────────────┘
```

## Authentication Flow

```
┌──────────┐                ┌──────────┐                ┌──────────┐
│  Client  │                │   KDC    │                │   File   │
│          │                │          │                │  Server  │
└────┬─────┘                └────┬─────┘                └────┬─────┘
     │                           │                           │
     │ 1. kinit user@REALM       │                           │
     ├──────────────────────────>│                           │
     │                           │                           │
     │ 2. TGT (Ticket Granting   │                           │
     │    Ticket)                │                           │
     │<──────────────────────────┤                           │
     │                           │                           │
     │ 3. Request service ticket │                           │
     │    for nfs/fileserver     │                           │
     ├──────────────────────────>│                           │
     │                           │                           │
     │ 4. Service ticket         │                           │
     │<──────────────────────────┤                           │
     │                           │                           │
     │ 5. Mount share with       │                           │
     │    service ticket         │                           │
     ├───────────────────────────────────────────────────────>│
     │                           │                           │
     │                           │ 6. Validate ticket        │
     │                           │<──────────────────────────┤
     │                           │                           │
     │                           │ 7. Ticket valid           │
     │                           ├──────────────────────────>│
     │                           │                           │
     │ 8. Access granted         │                           │
     │<───────────────────────────────────────────────────────┤
     │                           │                           │
```

## Network Ports

### Kerberos KDC
- **88/TCP, 88/UDP** - Kerberos authentication
- **464/TCP, 464/UDP** - Kerberos password changes (kpasswd)
- **749/TCP** - Kerberos admin (kadmin)

### File Server
- **445/TCP** - SMB/CIFS (Samba)
- **2049/TCP** - NFS version 4
- **111/TCP, 111/UDP** - RPC portmapper (NFS)

### Required for All Systems
- **22/TCP** - SSH (for Ansible)
- **123/UDP** - NTP (time synchronization)

## Data Flow

### Keytab Distribution

```
┌─────────────────────────────────────────────────────────────┐
│  KDC: Create and Export Keytabs                             │
│                                                              │
│  1. kadmin.local                                            │
│  2. addprinc -randkey nfs/fileserver@REALM                  │
│  3. addprinc -randkey cifs/fileserver@REALM                 │
│  4. ktadd -k /var/lib/krb5kdc/keytabs/fileserver.keytab ... │
│                                                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ scp keytab
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  File Server: Install Keytab                                │
│                                                              │
│  1. Receive keytab at /etc/krb5.keytab                      │
│  2. chmod 600 /etc/krb5.keytab                              │
│  3. chown root:root /etc/krb5.keytab                        │
│  4. Samba and NFS read keytab for authentication            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Share Access Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Client: Access Share                                        │
│                                                              │
│  1. kinit alice@CUBE.K8S                                    │
│  2. mount -t cifs //fileserver/share /mnt/share \           │
│     -o sec=krb5,user=alice                                  │
│                                                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ Kerberos ticket
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  File Server: Validate and Grant Access                     │
│                                                              │
│  1. Receive connection with Kerberos ticket                 │
│  2. Validate ticket using keytab                            │
│  3. Check share permissions (valid_users)                   │
│  4. Check filesystem permissions (owner, group, mode)       │
│  5. Grant or deny access                                    │
│  6. Log access attempt                                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Network Security                                   │
│  - Firewall rules (UFW/iptables)                            │
│  - Port restrictions                                         │
│  - Network segmentation                                      │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Kerberos Authentication                           │
│  - Strong encryption (AES256/AES128)                        │
│  - No plaintext passwords                                    │
│  - Ticket-based authentication                              │
│  - Time-limited tickets                                      │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Share-Level Authorization                         │
│  - Samba: valid_users, valid_groups                         │
│  - NFS: export restrictions (host-based)                    │
│  - Read-only vs read-write                                  │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: Filesystem Permissions                            │
│  - Unix permissions (owner, group, mode)                    │
│  - ACLs (optional)                                          │
│  - SELinux/AppArmor (optional)                              │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 5: Audit and Logging                                 │
│  - Samba logs: /var/log/samba/log.%m                       │
│  - NFS logs: systemd journal                                │
│  - KDC logs: /var/log/krb5kdc.log                          │
│  - Authentication attempts logged                            │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Sequence

```
Step 1: Deploy KDC
┌─────────────────────────────────────┐
│  ansible-playbook playbooks/kdc.yml │
└─────────────────────────────────────┘
              │
              ▼
Step 2: Create Principals
┌─────────────────────────────────────┐
│  kadmin.local                       │
│  addprinc -randkey nfs/fileserver   │
│  addprinc -randkey cifs/fileserver  │
│  addprinc alice@REALM               │
└─────────────────────────────────────┘
              │
              ▼
Step 3: Export Keytabs
┌─────────────────────────────────────┐
│  ktadd -k /tmp/fileserver.keytab    │
└─────────────────────────────────────┘
              │
              ▼
Step 4: Copy Keytabs
┌─────────────────────────────────────┐
│  scp keytab root@fileserver:/etc/   │
└─────────────────────────────────────┘
              │
              ▼
Step 5: Deploy File Server
┌─────────────────────────────────────┐
│  ansible-playbook playbooks/site.yml│
└─────────────────────────────────────┘
              │
              ▼
Step 6: Test Authentication
┌─────────────────────────────────────┐
│  kinit alice@REALM                  │
│  mount share                        │
└─────────────────────────────────────┘
```

## File Locations Reference

### KDC Server
```
/etc/krb5.conf                      # Kerberos client config
/etc/krb5kdc/kdc.conf              # KDC configuration
/etc/krb5kdc/kadm5.acl             # Admin ACL
/var/lib/krb5kdc/principal         # Kerberos database
/var/lib/krb5kdc/keytabs/          # Exported keytabs
/var/log/krb5kdc.log               # KDC logs
/var/log/kadmin.log                # Admin logs
```

### File Server
```
/etc/krb5.conf                      # Kerberos client config
/etc/krb5.keytab                    # Service keytab
/etc/samba/smb.conf                 # Samba configuration
/etc/exports                        # NFS exports
/var/log/samba/                     # Samba logs
/srv/shares/                        # Share directories
```

### Client
```
/etc/krb5.conf                      # Kerberos client config
/tmp/krb5cc_*                       # Ticket cache
~/.k5login                          # User Kerberos config
```

## Monitoring Points

```
┌─────────────────────────────────────────────────────────────┐
│  KDC Monitoring                                              │
│  - Service status: systemctl status krb5-kdc                │
│  - Failed auth: grep FAILED /var/log/krb5kdc.log           │
│  - Database size: du -sh /var/lib/krb5kdc/                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  File Server Monitoring                                      │
│  - Samba status: systemctl status smbd                      │
│  - NFS status: systemctl status nfs-server                  │
│  - Share access: tail -f /var/log/samba/log.*              │
│  - Disk usage: df -h /srv/shares/                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Client Monitoring                                           │
│  - Ticket status: klist                                     │
│  - Mount status: mount | grep cifs                          │
│  - Connection test: smbclient -L //server -k               │
└─────────────────────────────────────────────────────────────┘
```
