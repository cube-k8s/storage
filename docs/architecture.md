# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│  File Server (file-server.cube.k8s)                         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Kerberos KDC                                          │ │
│  │  - Port 88 (auth), 464 (password), 749 (admin)        │ │
│  │  - Database: /var/lib/krb5kdc/                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                           │                                  │
│                           │ Local auth                       │
│                           ▼                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  File Services                                        │  │
│  │  ┌──────────────┐              ┌──────────────┐      │  │
│  │  │    Samba     │              │     NFS      │      │  │
│  │  │  Port 445    │              │  Port 2049   │      │  │
│  │  └──────────────┘              └──────────────┘      │  │
│  │  Keytab: /etc/krb5.keytab                            │  │
│  │  Shares: /srv/shares/                                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │ Kerberos + SMB/NFS
                    ┌──────┴──────┐
                    │   Clients   │
                    └─────────────┘
```

## Authentication Flow

```
┌──────────┐                ┌──────────┐                ┌──────────┐
│  Client  │                │   KDC    │                │  Server  │
└────┬─────┘                └────┬─────┘                └────┬─────┘
     │                           │                           │
     │ 1. kinit user@REALM       │                           │
     ├──────────────────────────>│                           │
     │                           │                           │
     │ 2. TGT (Ticket Granting)  │                           │
     │<──────────────────────────┤                           │
     │                           │                           │
     │ 3. Request service ticket │                           │
     ├──────────────────────────>│                           │
     │                           │                           │
     │ 4. Service ticket         │                           │
     │<──────────────────────────┤                           │
     │                           │                           │
     │ 5. Mount with ticket      │                           │
     ├───────────────────────────────────────────────────────>│
     │                           │                           │
     │ 6. Access granted         │                           │
     │<───────────────────────────────────────────────────────┤
```

## Network Ports

| Port | Protocol | Service |
|------|----------|---------|
| 88 | TCP/UDP | Kerberos auth |
| 464 | TCP/UDP | Kerberos password |
| 749 | TCP | Kerberos admin |
| 445 | TCP | SMB/CIFS |
| 2049 | TCP | NFS |
| 111 | TCP/UDP | RPC portmapper |

## Security Layers

```
┌─────────────────────────────────────────┐
│  Layer 1: Network (Firewall)            │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│  Layer 2: Kerberos Authentication       │
│  - AES256/AES128 encryption             │
│  - Ticket-based, time-limited           │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│  Layer 3: Share Authorization           │
│  - Samba: valid_users                   │
│  - NFS: export restrictions             │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│  Layer 4: Filesystem Permissions        │
│  - Unix permissions (owner/group/mode)  │
└─────────────────────────────────────────┘
```

## File Locations

### Server
```
/etc/krb5.conf              # Kerberos config
/etc/krb5kdc/kdc.conf       # KDC config
/etc/krb5kdc/kadm5.acl      # Admin ACL
/etc/krb5.keytab            # Service keytab
/etc/samba/smb.conf         # Samba config
/etc/exports                # NFS exports
/srv/shares/                # Share directories
/var/log/krb5kdc.log        # KDC logs
/var/log/samba/             # Samba logs
```

### Client
```
/etc/krb5.conf              # Kerberos config
/etc/krb5.keytab            # Machine keytab (for NFS clients)
/tmp/krb5cc_*               # Ticket cache
```

## NFS Export Configuration

Current exports use `all_squash` for Kubernetes compatibility:

```
/srv/shares/socialpro *(rw,sync,sec=krb5:krb5i:krb5p,all_squash,anonuid=1001,anongid=100)
```

This maps all client UIDs to `gustavo:users`, solving pod permission issues.
