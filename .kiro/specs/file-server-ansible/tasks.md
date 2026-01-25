# Implementation Plan: Home Lab File Server

## Overview

This implementation plan breaks down the deployment of a Kerberos-authenticated file server into discrete Ansible development tasks. The approach follows infrastructure-as-code principles, creating reusable roles and playbooks for deploying SMB and NFS file sharing with Kerberos authentication on Debian systems.

## Tasks

- [x] 1. Set up Ansible project structure and base configuration
  - Create directory structure (roles/, playbooks/, group_vars/, host_vars/, templates/, inventory/)
  - Create ansible.cfg with sensible defaults
  - Create inventory file with file server host definition
  - Create main playbook (site.yml) that includes role references
  - _Requirements: 4.1, 8.1_

- [x] 2. Implement common role for base system configuration
  - [x] 2.1 Create common role structure and tasks
    - Create role directory structure (tasks/, defaults/, handlers/)
    - Write tasks for apt cache update
    - Write tasks for base package installation (python3, acl, attr)
    - Define default variables for base packages
    - _Requirements: 4.2_
  
  - [ ]* 2.2 Write property test for package installation
    - **Property 5: Package Installation Completeness**
    - **Validates: Requirements 4.2**

- [ ] 3. Implement kerberos-client role
  - [x] 3.1 Create Kerberos client configuration tasks
    - Create role directory structure
    - Write tasks to install krb5-user and libpam-krb5 packages
    - Create krb5.conf.j2 template with realm, KDC, and domain_realm sections
    - Write task to template krb5.conf to /etc/krb5.conf
    - Define variables for krb5_realm, krb5_kdc, krb5_admin_server
    - _Requirements: 3.1, 4.5, 10.1, 10.2_
  
  - [x] 3.2 Implement service principal and keytab management
    - Write tasks to create service principals using kadmin (conditional on kadmin credentials)
    - Write tasks to export keytabs using kadmin
    - Write tasks to copy pre-existing keytabs (alternative to kadmin)
    - Set proper permissions on keytab files (0600, owned by root)
    - Add validation task to test Kerberos config with kinit
    - _Requirements: 3.3, 3.4, 10.3, 10.4, 10.5_
  
  - [ ]* 3.3 Write unit tests for Kerberos client role
    - Test krb5.conf is templated correctly with test variables
    - Test keytab file exists and has correct permissions
    - Test kinit validation works with valid keytab
    - Test error handling for invalid keytab (edge case)
    - _Requirements: 3.5_

- [ ] 4. Implement shares role for storage management
  - [x] 4.1 Create share directory management tasks
    - Create role directory structure
    - Write tasks to create share directories from shares variable list
    - Write tasks to set ownership (owner, group) on directories
    - Write tasks to set permissions (mode) on directories
    - Define shares variable structure with path, owner, group, mode fields
    - _Requirements: 5.1, 5.2, 5.4_
  
  - [ ]* 4.2 Write property tests for share management
    - **Property 7: Share Directory Creation and Permissions**
    - **Validates: Requirements 5.2, 5.4**
    - **Property 8: Configurable Storage Paths**
    - **Validates: Requirements 5.1**

- [x] 5. Checkpoint - Validate base infrastructure
  - Run playbooks on test Debian system
  - Verify Kerberos client configuration (kinit should work)
  - Verify share directories exist with correct permissions
  - Ensure all tests pass, ask the user if questions arise

- [ ] 6. Implement samba role for SMB file sharing
  - [x] 6.1 Create Samba installation and configuration tasks
    - Create role directory structure
    - Write tasks to install samba, samba-common-bin, winbind packages
    - Create smb.conf.j2 template with global section (workgroup, realm, security, kerberos method)
    - Create smb.conf.j2 template with share sections (loop over samba_shares variable)
    - Write task to template smb.conf to /etc/samba/smb.conf
    - Define variables for samba_workgroup, samba_realm, samba_security, samba_shares
    - _Requirements: 1.1, 4.3_
  
  - [x] 6.2 Configure Samba service management
    - Write tasks to enable smbd, nmbd, winbind services
    - Create handler to restart smbd when config changes
    - Create handler to reload smbd when minor changes occur
    - Write task to ensure services are started
    - Configure systemd dependencies (After=network.target, After=krb5-kdc.service if local KDC)
    - _Requirements: 7.1, 7.4_
  
  - [x] 6.3 Configure Samba Kerberos integration
    - Write task to set Samba to use Kerberos keytab
    - Configure dedicated keytab file path in smb.conf
    - Write task to validate Samba can read keytab
    - Add logging configuration to smb.conf template (log level, log file per client)
    - _Requirements: 1.2, 9.3_
  
  - [ ]* 6.4 Write unit tests for Samba role
    - Test smb.conf is generated correctly with test variables
    - Test Samba services are enabled and running
    - Test Samba can read keytab file
    - Test smb.conf contains all configured shares
    - _Requirements: 1.1, 1.4_

- [ ] 7. Implement nfs-server role for NFS file sharing
  - [x] 7.1 Create NFS server installation and configuration tasks
    - Create role directory structure
    - Write tasks to install nfs-kernel-server and nfs-common packages
    - Create exports.j2 template (loop over nfs_exports variable)
    - Write task to template exports to /etc/exports
    - Define variables for nfs_exports with path, clients, options structure
    - _Requirements: 2.1, 4.4_
  
  - [x] 7.2 Configure NFS Kerberos integration
    - Write tasks to configure /etc/default/nfs-kernel-server (NEED_GSSD=yes, NEED_SVCGSSD=yes)
    - Write tasks to configure /etc/default/nfs-common (NEED_GSSD=yes)
    - Write task to ensure rpc-gssd service is enabled and started
    - Write task to ensure rpc-svcgssd service is enabled and started
    - _Requirements: 2.2_
  
  - [x] 7.3 Configure NFS service management
    - Write tasks to enable nfs-server service
    - Create handler to restart nfs-server when exports change
    - Create handler to reload nfs-server for minor changes
    - Write task to exportfs -ra to apply export changes
    - Configure systemd dependencies (After=network.target, After=rpc-gssd.service)
    - _Requirements: 7.2, 7.4_
  
  - [ ]* 7.4 Write unit tests for NFS role
    - Test /etc/exports is generated correctly with test variables
    - Test NFS services are enabled and running
    - Test rpc-gssd and rpc-svcgssd are running
    - Test exports contain sec=krb5 options
    - _Requirements: 2.1, 2.4, 2.5_

- [x] 8. Checkpoint - Validate file services
  - Run complete playbook on test system
  - Verify Samba is running and listening on port 445
  - Verify NFS is running and listening on port 2049
  - Verify services start automatically after reboot
  - Ensure all tests pass, ask the user if questions arise

- [x] 9. Implement configuration validation and error handling
  - [x] 9.1 Add configuration validation tasks
    - Write assert tasks to validate krb5_realm is defined and non-empty
    - Write assert tasks to validate krb5_kdc is defined and non-empty
    - Write assert tasks to validate shares list is defined
    - Write assert tasks to validate share paths are absolute paths
    - Add validation for samba_shares and nfs_exports structure
    - _Requirements: 8.4, 8.5_
  
  - [ ]* 9.2 Write property test for configuration validation
    - **Property 13: Configuration Validation**
    - **Validates: Requirements 8.4, 8.5**

- [ ] 10. Implement logging configuration
  - [ ] 10.1 Configure Samba logging
    - Update smb.conf.j2 template with detailed logging settings
    - Set log level to capture authentication attempts (auth:5, winbind:5)
    - Configure per-client log files (log file = /var/log/samba/log.%m)
    - Set max log size to prevent disk fill
    - _Requirements: 9.1, 9.2, 9.3, 9.5_
  
  - [ ] 10.2 Configure NFS logging
    - Write tasks to configure NFS to log to systemd journal
    - Set appropriate log levels for rpc.gssd and rpc.svcgssd
    - Add tasks to configure rsyslog for NFS if needed
    - _Requirements: 9.4_
  
  - [ ]* 10.3 Write property tests for logging
    - **Property 10: Authentication Logging Completeness**
    - **Validates: Requirements 9.1, 9.5**
    - **Property 11: Access Logging Completeness**
    - **Validates: Requirements 9.2**
    - **Property 12: Access Denial Logging**
    - **Validates: Requirements 6.5**

- [ ] 11. Implement access control configuration
  - [ ] 11.1 Configure Samba access controls
    - Update smb.conf.j2 template to support valid_users and valid_groups
    - Add support for read_only vs read-write shares
    - Configure create_mask and directory_mask per share
    - Add support for browseable setting per share
    - _Requirements: 6.1, 6.2, 6.3, 6.4_
  
  - [ ] 11.2 Configure NFS access controls
    - Update exports.j2 template to support multiple security levels (sec=krb5:krb5i:krb5p)
    - Add support for per-client export options
    - Configure fsid for each export to ensure consistent file handles
    - Add support for read-only vs read-write exports
    - _Requirements: 6.1, 6.2, 6.3_
  
  - [ ]* 11.3 Write property tests for access control
    - **Property 2: Permission-Based Access Control**
    - **Validates: Requirements 1.3, 2.3, 6.1, 6.2**
    - **Property 3: Share Enumeration Matches Permissions**
    - **Validates: Requirements 1.5**

- [ ] 12. Implement service restart and reload handlers
  - [ ] 12.1 Create comprehensive handler definitions
    - Create handler to restart smbd service
    - Create handler to reload smbd service
    - Create handler to restart nfs-server service
    - Create handler to reload nfs-server (exportfs -ra)
    - Create handler to restart rpc-gssd and rpc-svcgssd
    - _Requirements: 7.5_
  
  - [ ] 12.2 Add handler notifications to tasks
    - Add notify to smb.conf template task
    - Add notify to exports template task
    - Add notify to NFS config file changes
    - Add notify to keytab updates
    - _Requirements: 7.5_
  
  - [ ]* 12.3 Write property test for service restart
    - **Property 9: Service Restart on Configuration Change**
    - **Validates: Requirements 7.5**

- [ ] 13. Implement idempotency and configuration management
  - [ ] 13.1 Ensure all tasks are idempotent
    - Review all tasks for idempotency (use creates, when conditions)
    - Ensure package tasks use state=present (not latest)
    - Ensure file tasks check for changes before notifying handlers
    - Add changed_when conditions where appropriate
    - _Requirements: 4.6_
  
  - [ ]* 13.2 Write property tests for idempotency and configuration
    - **Property 4: Ansible Idempotency**
    - **Validates: Requirements 4.6, 5.5**
    - **Property 6: Configuration Variable Propagation**
    - **Validates: Requirements 8.2, 4.7**

- [ ] 14. Create example variable files and documentation
  - [ ] 14.1 Create example configurations
    - Create group_vars/fileservers.yml with example variables
    - Create host_vars/fileserver01.yml with host-specific examples
    - Document all variables in defaults/main.yml for each role
    - Create example inventory file with proper host groups
    - _Requirements: 8.1_
  
  - [ ] 14.2 Create README and usage documentation
    - Write README.md with project overview
    - Document prerequisites (Debian system, Kerberos KDC)
    - Document variable configuration
    - Provide example playbook runs
    - Document troubleshooting steps

- [ ] 15. Final checkpoint - Integration testing
  - [ ] 15.1 Test complete deployment
    - Deploy to fresh Debian VM using playbooks
    - Verify all services start correctly
    - Test SMB connection from Linux client with Kerberos
    - Test NFS mount from Linux client with sec=krb5
    - Verify authentication and access control work correctly
    - _Requirements: 1.2, 1.3, 2.2, 2.3_
  
  - [ ]* 15.2 Write integration tests
    - Test complete deployment workflow
    - Test client connectivity (SMB and NFS)
    - Test authentication with valid and invalid credentials
    - Test access control enforcement
    - Test service restart and recovery
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 6.1, 6.2_

- [ ] 16. Optional: Implement MIT Kerberos KDC deployment role
  - [ ] 16.1 Create kerberos-kdc role (optional)
    - Create role for deploying MIT Kerberos KDC
    - Write tasks to install krb5-kdc and krb5-admin-server
    - Create kdc.conf and kadm5.acl templates
    - Write tasks to initialize Kerberos database
    - Write tasks to create admin principal
    - Configure KDC and kadmin services
    - _Requirements: 10.3_
  
  - [ ] 16.2 Create KDC deployment playbook (optional)
    - Create separate playbook for KDC deployment
    - Document KDC setup process
    - Provide example variables for KDC configuration

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- The implementation uses Ansible best practices (roles, handlers, templates, variables)
- All configuration is managed as code for reproducibility
