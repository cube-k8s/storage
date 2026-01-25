# Montando NFS com Kerberos no macOS

Este guia explica como montar compartilhamentos NFS com autenticação Kerberos no macOS.

## Pré-requisitos

1. macOS configurado como cliente Kerberos (ver `client-kerberos-setup.md`)
2. Ticket Kerberos válido (`kinit usuario@REALM`)
3. Servidor NFS configurado com `sec=krb5`

## Configuração do Kerberos no macOS

### 1. Configurar /etc/krb5.conf

```bash
sudo nano /etc/krb5.conf
```

```ini
[libdefaults]
    default_realm = CUBE.K8S
    dns_lookup_realm = false
    dns_lookup_kdc = false

[realms]
    CUBE.K8S = {
        kdc = kdc.cube.k8s
        admin_server = kdc.cube.k8s
    }

[domain_realm]
    .cube.k8s = CUBE.K8S
    cube.k8s = CUBE.K8S
```

### 2. Obter ticket Kerberos

```bash
kinit usuario@CUBE.K8S
klist  # Verificar ticket
```

## Montagem NFS

### Montagem Manual

```bash
# Criar ponto de montagem
sudo mkdir -p /Volumes/socialpro

# Montar com Kerberos (sec=krb5)
sudo mount -t nfs -o sec=krb5,vers=4 file-server.cube.k8s:/srv/shares/socialpro /Volumes/socialpro
```

### Opções de Segurança

| Opção | Descrição |
|-------|-----------|
| `sec=krb5` | Autenticação Kerberos |
| `sec=krb5i` | Autenticação + integridade |
| `sec=krb5p` | Autenticação + criptografia (mais seguro) |

```bash
# Com criptografia completa
sudo mount -t nfs -o sec=krb5p,vers=4 file-server.cube.k8s:/srv/shares/socialpro /Volumes/socialpro
```

### Montagem Automática com autofs

1. Editar `/etc/auto_master`:

```bash
sudo nano /etc/auto_master
```

Adicionar:
```
/Volumes/nfs    auto_nfs    -nosuid,nodev
```

2. Criar `/etc/auto_nfs`:

```bash
sudo nano /etc/auto_nfs
```

```
socialpro    -fstype=nfs,sec=krb5,vers=4    file-server.cube.k8s:/srv/shares/socialpro
```

3. Reiniciar autofs:

```bash
sudo automount -vc
```

4. Acessar (monta automaticamente):

```bash
cd /Volumes/nfs/socialpro
```

## Solução de Problemas

### Erro: "Operation not permitted"

Verificar se tem ticket Kerberos válido:
```bash
klist
# Se expirado:
kinit usuario@CUBE.K8S
```

### Erro: "mount_nfs: can't mount ... Permission denied"

1. Verificar se o servidor exporta para seu IP:
```bash
showmount -e file-server.cube.k8s
```

2. Verificar se o principal do usuário existe no KDC

### Erro: "No credentials cache found"

Obter ticket primeiro:
```bash
kinit usuario@CUBE.K8S
```

### Verificar conectividade NFS

```bash
# Testar porta NFS
nc -zv file-server.cube.k8s 2049

# Listar exports
showmount -e file-server.cube.k8s
```

### Debug de montagem

```bash
# Montagem com verbose
sudo mount -t nfs -o sec=krb5,vers=4 -v file-server.cube.k8s:/srv/shares/socialpro /Volumes/socialpro
```

## Desmontar

```bash
sudo umount /Volumes/socialpro
```

## Dicas

- Sempre obtenha um ticket Kerberos antes de montar
- Use `sec=krb5p` para máxima segurança (dados criptografados)
- Configure autofs para montagem automática sob demanda
- Tickets expiram - configure renovação automática se necessário
