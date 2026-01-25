# Client Kerberos Configuration

## Overview

To authenticate to the file server using Kerberos, client machines need to have the Kerberos client configured to point to the KDC.

## Prerequisites

- Network connectivity to the KDC/file server (file-server.cube.k8s at 10.10.10.110)
- Kerberos client packages installed

## Installation

### On Debian/Ubuntu:
```bash
sudo apt-get update
sudo apt-get install krb5-user
```

### On macOS:
Kerberos client is pre-installed. Just configure `/etc/krb5.conf`.

### On RHEL/CentOS:
```bash
sudo yum install krb5-workstation
```

## Configuration

### Option 1: Manual Configuration

Create or edit `/etc/krb5.conf` with the following content:

```ini
[libdefaults]
    default_realm = CUBE.K8S
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false

[realms]
    CUBE.K8S = {
        kdc = file-server.cube.k8s
        admin_server = file-server.cube.k8s
    }

[domain_realm]
    .cube.k8s = CUBE.K8S
    cube.k8s = CUBE.K8S
```

**Important**: Make sure `file-server.cube.k8s` resolves to the correct IP address (10.10.10.110). Add to `/etc/hosts` if needed:

```bash
echo "10.10.10.110 file-server.cube.k8s file-server" | sudo tee -a /etc/hosts
```

### Option 2: Copy from File Server

If you have SSH access to the file server, you can copy the configuration:

```bash
scp root@file-server.cube.k8s:/etc/krb5.conf /tmp/krb5.conf
sudo cp /tmp/krb5.conf /etc/krb5.conf
```

## Testing Authentication

### 1. Test kinit

Obtain a Kerberos ticket for the gustavo user:

```bash
kinit gustavo@CUBE.K8S
# Password: JpMMf@Gm0
```

### 2. Verify the ticket

```bash
klist
```

Expected output:
```
Ticket cache: FILE:/tmp/krb5cc_1000
Default principal: gustavo@CUBE.K8S

Valid starting     Expires            Service principal
01/22/26 18:30:00  01/23/26 18:30:00  krbtgt/CUBE.K8S@CUBE.K8S
```

### 3. Destroy the ticket (when done)

```bash
kdestroy
```

## Available User Principals

The following user principals are configured in the KDC:

- `gustavo@CUBE.K8S` - Password: `JpMMf@Gm0`
- `miria@CUBE.K8S` - Password: `m1r1@`
- `admin/admin@CUBE.K8S` - Password: `JpMMf@Gm0` (admin principal)

## Troubleshooting

### Error: "Cannot find KDC for realm"

**Problem**: Client cannot locate the KDC server.

**Solutions**:
1. Check `/etc/krb5.conf` has the correct KDC address
2. Verify network connectivity: `ping file-server.cube.k8s`
3. Verify DNS resolution or add to `/etc/hosts`
4. Check firewall allows port 88 (TCP/UDP)

### Error: "CLIENT_NOT_FOUND"

**Problem**: The principal doesn't exist in the KDC.

**Solution**: Create the principal on the KDC:
```bash
ssh root@file-server.cube.k8s
kadmin.local
addprinc username@CUBE.K8S
quit
```

### Error: "Preauthentication failed"

**Problem**: Wrong password.

**Solution**: Reset the password on the KDC:
```bash
ssh root@file-server.cube.k8s
kadmin.local
cpw username@CUBE.K8S
quit
```

### Error: "Clock skew too great"

**Problem**: Time difference between client and KDC is more than 5 minutes.

**Solution**: Synchronize time on both machines:
```bash
sudo ntpdate pool.ntp.org
# or
sudo systemctl restart systemd-timesyncd
```

## Next Steps

Once Kerberos authentication is working:

1. **Mount SMB share**: See `docs/user-management-and-mounting.md`
2. **Mount NFS share**: See `docs/user-management-and-mounting.md`
3. **Test access control**: Verify you can only access authorized shares

## Quick Test Script

Save this as `test-kerberos.sh`:

```bash
#!/bin/bash
# Quick Kerberos authentication test

echo "Testing Kerberos authentication..."
echo ""

# Test kinit
echo "Obtaining ticket for gustavo@CUBE.K8S..."
echo "JpMMf@Gm0" | kinit gustavo@CUBE.K8S

if [ $? -eq 0 ]; then
    echo "✓ Authentication successful!"
    echo ""
    echo "Ticket information:"
    klist
    echo ""
    echo "Cleaning up..."
    kdestroy
    echo "✓ Test complete"
else
    echo "✗ Authentication failed"
    exit 1
fi
```

Make it executable and run:
```bash
chmod +x test-kerberos.sh
./test-kerberos.sh
```
