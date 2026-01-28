# Troubleshooting Guide

Common issues and solutions for Kerberos NFS/SMB.

## Quick Diagnostics

```bash
# Check Kerberos ticket
klist

# Check server services
ssh root@file-server.cube.k8s "systemctl status krb5-kdc nfs-server smbd rpc-svcgssd"

# Check client services (on worker nodes)
systemctl status rpc-gssd

# Check keytabs
klist -k /etc/krb5.keytab

# Check exports
ssh root@file-server.cube.k8s "exportfs -v"

# Check logs
ssh root@file-server.cube.k8s "journalctl -u rpc-svcgssd -n 50"
```

## Common Issues

### "access denied by server while mounting"

**Most common cause: Keytab out of date**

Check server logs:
```bash
ssh root@file-server.cube.k8s "journalctl -u rpc-svcgssd -n 50"
```

If you see "kvno X not found in keytab":

```bash
# Update server keytab
ssh root@file-server.cube.k8s
cd /var/lib/krb5kdc/keytabs
kadmin.local -q 'ktadd -k nfs_file-server.cube.k8s_CUBE.K8S.keytab nfs/file-server.cube.k8s@CUBE.K8S'
kadmin.local -q 'ktadd -k cifs_file-server.cube.k8s_CUBE.K8S.keytab cifs/file-server.cube.k8s@CUBE.K8S'

# Merge keytabs
rm -f /etc/krb5.keytab
(echo 'read_kt nfs_file-server.cube.k8s_CUBE.K8S.keytab'; \
 echo 'read_kt cifs_file-server.cube.k8s_CUBE.K8S.keytab'; \
 echo 'write_kt /etc/krb5.keytab'; \
 echo 'quit') | ktutil
chmod 600 /etc/krb5.keytab
systemctl restart rpc-svcgssd
```

### "Cannot contact any KDC"

```bash
# Check KDC is running
ssh root@file-server.cube.k8s "systemctl status krb5-kdc"
ssh root@file-server.cube.k8s "ss -tulpn | grep :88"

# Test connectivity from client
telnet file-server.cube.k8s 88
ping file-server.cube.k8s
```

### "Clock skew too great"

Time difference must be < 5 minutes:

```bash
# Check time
date

# Sync time
sudo timedatectl set-ntp true

# macOS
sudo sntp -sS time.apple.com
```

### "No credentials found"

```bash
# Check keytab exists
ls -la /etc/krb5.keytab

# Check permissions
chmod 600 /etc/krb5.keytab

# Check contents
klist -k /etc/krb5.keytab

# Restart rpc-gssd
systemctl restart rpc-gssd
```

### "Principal does not exist"

```bash
# List principals
ssh root@file-server.cube.k8s "kadmin.local -q 'listprincs'"

# Create missing principal
ssh root@file-server.cube.k8s "kadmin.local -q 'addprinc user@CUBE.K8S'"
```

### "Preauthentication failed"

Wrong password:
```bash
# Reset password
ssh root@file-server.cube.k8s "kadmin.local -q 'cpw user@CUBE.K8S'"
```

### Kubernetes Pod Mount Fails

```bash
# Find worker node
kubectl get pod <pod-name> -o wide

# SSH to worker and test manually
ssh root@<worker-node>
mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/path /mnt/test

# If manual mount fails, fix the issue
# Then delete pod to retry
kubectl delete pod <pod-name>
```

### Permission Denied After Mount

```bash
# Check directory permissions on server
ssh root@file-server.cube.k8s "ls -la /srv/shares/"

# Fix permissions
ssh root@file-server.cube.k8s "chown -R gustavo:users /srv/shares/path && chmod -R 775 /srv/shares/path"
```

## Ansible Playbooks for Fixes

```bash
# Regenerate all principals and keytabs
ansible-playbook -i inventory/hosts.yml playbooks/kdc.yml --tags principals,keytabs

# Deploy keytabs to clients
ansible-playbook -i inventory/hosts.yml playbooks/deploy-nfs-client-keytabs.yml

# Reconfigure NFS server
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags nfs

# Reconfigure NFS clients
ansible-playbook -i inventory/hosts.yml playbooks/nfs-client.yml
```

## Debug Commands

### Server Side

```bash
ssh root@file-server.cube.k8s

# Check all services
systemctl status krb5-kdc krb5-admin-server nfs-server smbd rpc-svcgssd

# Check keytab
klist -k /etc/krb5.keytab

# Check exports
exportfs -v
cat /etc/exports

# Check logs
journalctl -u rpc-svcgssd -n 50
journalctl -u nfs-server -n 50
tail -f /var/log/krb5kdc.log
```

### Client Side

```bash
# Check ticket
klist

# Check keytab
klist -k /etc/krb5.keytab

# Check rpc-gssd
systemctl status rpc-gssd
journalctl -u rpc-gssd -n 50

# Test mount with verbose
mount -t nfs -o sec=krb5,vers=4,v file-server.cube.k8s:/srv/shares/path /mnt/test
```

### KDC

```bash
ssh root@file-server.cube.k8s

# Check principal
kadmin.local -q 'getprinc nfs/file-server.cube.k8s@CUBE.K8S'

# List all NFS principals
kadmin.local -q 'listprincs nfs/*'

# Check keytab version matches
klist -k /etc/krb5.keytab | grep nfs
kadmin.local -q 'getprinc nfs/file-server.cube.k8s@CUBE.K8S' | grep -i kvno
```

## Quick Fix Workflow

1. **Check server logs first:**
   ```bash
   ssh root@file-server.cube.k8s "journalctl -u rpc-svcgssd -n 20"
   ```

2. **If "kvno not found":** Update server keytab (see above)

3. **Check client logs:**
   ```bash
   journalctl -u rpc-gssd -n 20
   ```

4. **If "No credentials":** Redeploy client keytabs:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-nfs-client-keytabs.yml
   ```

5. **Test mount:**
   ```bash
   mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/path /mnt/test
   ```
