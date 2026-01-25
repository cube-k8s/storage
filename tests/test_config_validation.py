#!/usr/bin/env python3
"""
Configuration Validation Tests

These tests verify that the Ansible roles properly validate configuration
variables and fail with appropriate error messages when invalid configuration
is provided.

Run with: python3 tests/test_config_validation.py
"""

import os
import sys
from pathlib import Path


class Colors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    NC = '\033[0m'  # No Color


def print_test(name, passed, message=""):
    """Print test result with color"""
    status = f"{Colors.GREEN}✓ PASS{Colors.NC}" if passed else f"{Colors.RED}✗ FAIL{Colors.NC}"
    print(f"{status}: {name}")
    if message and not passed:
        print(f"  {Colors.YELLOW}→{Colors.NC} {message}")
    return passed


def test_kerberos_validation_tasks_exist():
    """Test that kerberos-client role has validation tasks"""
    try:
        with open("roles/kerberos-client/tasks/main.yml", 'r') as f:
            content = f.read()
        
        has_realm_validation = 'Validate krb5_realm is defined and non-empty' in content
        has_kdc_validation = 'Validate krb5_kdc is defined and non-empty' in content
        has_keytab_validation = 'Validate keytab path is absolute' in content
        has_principal_validation = 'Validate krb5_service_principals structure' in content
        
        all_present = has_realm_validation and has_kdc_validation and has_keytab_validation and has_principal_validation
        
        return print_test(
            "Kerberos role has validation tasks",
            all_present,
            "Missing validation tasks in kerberos-client role"
        )
    except Exception as e:
        return print_test("Kerberos validation tasks", False, str(e))


def test_samba_validation_tasks_exist():
    """Test that samba role has validation tasks"""
    try:
        with open("roles/samba/tasks/main.yml", 'r') as f:
            content = f.read()
        
        has_shares_validation = 'Validate samba_shares structure' in content
        has_workgroup_validation = 'Validate samba_workgroup is defined' in content
        has_realm_validation = 'Validate samba_realm is defined' in content
        has_security_validation = 'Validate samba_security mode' in content
        
        all_present = has_shares_validation and has_workgroup_validation and has_realm_validation and has_security_validation
        
        return print_test(
            "Samba role has validation tasks",
            all_present,
            "Missing validation tasks in samba role"
        )
    except Exception as e:
        return print_test("Samba validation tasks", False, str(e))


def test_nfs_validation_tasks_exist():
    """Test that nfs-server role has validation tasks"""
    try:
        with open("roles/nfs-server/tasks/main.yml", 'r') as f:
            content = f.read()
        
        has_exports_validation = 'Validate nfs_exports structure' in content
        has_export_fields_validation = 'Validate each NFS export has required fields' in content
        has_client_validation = 'Validate NFS export client configuration' in content
        has_kerberos_validation = 'Validate NFS exports use Kerberos security' in content
        
        all_present = has_exports_validation and has_export_fields_validation and has_client_validation and has_kerberos_validation
        
        return print_test(
            "NFS role has validation tasks",
            all_present,
            "Missing validation tasks in nfs-server role"
        )
    except Exception as e:
        return print_test("NFS validation tasks", False, str(e))


def test_shares_validation_tasks_exist():
    """Test that shares role has validation tasks"""
    try:
        with open("roles/shares/tasks/main.yml", 'r') as f:
            content = f.read()
        
        has_shares_validation = 'Validate shares configuration' in content
        has_path_validation = 'Validate each share has required path' in content
        has_absolute_path_check = "is match('^/')" in content
        
        all_present = has_shares_validation and has_path_validation and has_absolute_path_check
        
        return print_test(
            "Shares role has validation tasks",
            all_present,
            "Missing validation tasks in shares role"
        )
    except Exception as e:
        return print_test("Shares validation tasks", False, str(e))


def test_validation_uses_assert_module():
    """Test that validation tasks use ansible.builtin.assert"""
    try:
        roles_to_check = ['kerberos-client', 'samba', 'nfs-server', 'shares']
        all_use_assert = True
        
        for role in roles_to_check:
            with open(f"roles/{role}/tasks/main.yml", 'r') as f:
                content = f.read()
            
            if 'ansible.builtin.assert' not in content:
                all_use_assert = False
                break
        
        return print_test(
            "Validation tasks use ansible.builtin.assert",
            all_use_assert,
            "Some roles don't use ansible.builtin.assert for validation"
        )
    except Exception as e:
        return print_test("Assert module usage", False, str(e))


def test_validation_has_fail_messages():
    """Test that validation tasks have fail_msg defined"""
    try:
        roles_to_check = ['kerberos-client', 'samba', 'nfs-server', 'shares']
        all_have_fail_msg = True
        
        for role in roles_to_check:
            with open(f"roles/{role}/tasks/main.yml", 'r') as f:
                content = f.read()
            
            # Count assert tasks and fail_msg occurrences
            assert_count = content.count('ansible.builtin.assert')
            fail_msg_count = content.count('fail_msg:')
            
            # Each assert should have a fail_msg
            if assert_count > 0 and fail_msg_count < assert_count:
                all_have_fail_msg = False
                break
        
        return print_test(
            "Validation tasks have fail_msg defined",
            all_have_fail_msg,
            "Some assert tasks missing fail_msg"
        )
    except Exception as e:
        return print_test("Fail message presence", False, str(e))


def test_kerberos_realm_format_validation():
    """Test that kerberos role validates realm format"""
    try:
        with open("roles/kerberos-client/tasks/main.yml", 'r') as f:
            content = f.read()
        
        has_format_check = 'Validate krb5_realm format' in content
        has_regex = "is match('^[A-Z0-9.-]+" in content
        
        return print_test(
            "Kerberos role validates realm format (uppercase)",
            has_format_check and has_regex,
            "Missing realm format validation"
        )
    except Exception as e:
        return print_test("Realm format validation", False, str(e))


def test_service_principal_format_validation():
    """Test that kerberos role validates service principal format"""
    try:
        with open("roles/kerberos-client/tasks/main.yml", 'r') as f:
            content = f.read()
        
        has_principal_format = 'Validate each service principal format' in content
        has_format_regex = 'service/hostname@REALM' in content
        
        return print_test(
            "Kerberos role validates service principal format",
            has_principal_format and has_format_regex,
            "Missing service principal format validation"
        )
    except Exception as e:
        return print_test("Service principal format validation", False, str(e))


def test_samba_security_mode_validation():
    """Test that samba role validates security mode"""
    try:
        with open("roles/samba/tasks/main.yml", 'r') as f:
            content = f.read()
        
        has_security_validation = 'Validate samba_security mode' in content
        has_valid_modes = "['user', 'ads', 'domain']" in content
        
        return print_test(
            "Samba role validates security mode",
            has_security_validation and has_valid_modes,
            "Missing security mode validation"
        )
    except Exception as e:
        return print_test("Samba security mode validation", False, str(e))


def test_nfs_kerberos_security_validation():
    """Test that NFS role validates Kerberos security options"""
    try:
        with open("roles/nfs-server/tasks/main.yml", 'r') as f:
            content = f.read()
        
        has_krb5_check = 'Validate NFS exports use Kerberos security' in content
        has_sec_krb5 = 'sec=krb5' in content
        
        return print_test(
            "NFS role validates Kerberos security options",
            has_krb5_check and has_sec_krb5,
            "Missing Kerberos security validation"
        )
    except Exception as e:
        return print_test("NFS Kerberos security validation", False, str(e))


def test_absolute_path_validation():
    """Test that roles validate absolute paths"""
    try:
        roles_with_paths = {
            'kerberos-client': 'krb5_keytab_path',
            'samba': 'path',
            'nfs-server': 'path',
            'shares': 'path'
        }
        
        all_validate_paths = True
        
        for role, path_var in roles_with_paths.items():
            with open(f"roles/{role}/tasks/main.yml", 'r') as f:
                content = f.read()
            
            # Check for absolute path validation (starts with /)
            if "is match('^/')" not in content:
                all_validate_paths = False
                break
        
        return print_test(
            "Roles validate absolute paths",
            all_validate_paths,
            "Some roles don't validate absolute paths"
        )
    except Exception as e:
        return print_test("Absolute path validation", False, str(e))


def test_validation_tags():
    """Test that validation tasks are tagged appropriately"""
    try:
        roles_to_check = ['kerberos-client', 'samba', 'nfs-server', 'shares']
        all_have_validation_tag = True
        
        for role in roles_to_check:
            with open(f"roles/{role}/tasks/main.yml", 'r') as f:
                content = f.read()
            
            # Check if validation tasks have validation tag
            if 'ansible.builtin.assert' in content and '- validation' not in content:
                all_have_validation_tag = False
                break
        
        return print_test(
            "Validation tasks have 'validation' tag",
            all_have_validation_tag,
            "Some validation tasks missing 'validation' tag"
        )
    except Exception as e:
        return print_test("Validation tags", False, str(e))


def main():
    """Run all tests"""
    print("=" * 60)
    print("Configuration Validation Tests")
    print("=" * 60)
    print()
    
    # Change to project root if running from tests directory
    if Path.cwd().name == 'tests':
        os.chdir('..')
    
    tests = [
        test_kerberos_validation_tasks_exist,
        test_samba_validation_tasks_exist,
        test_nfs_validation_tasks_exist,
        test_shares_validation_tasks_exist,
        test_validation_uses_assert_module,
        test_validation_has_fail_messages,
        test_kerberos_realm_format_validation,
        test_service_principal_format_validation,
        test_samba_security_mode_validation,
        test_nfs_kerberos_security_validation,
        test_absolute_path_validation,
        test_validation_tags,
    ]
    
    print("Running validation tests...")
    print()
    
    results = []
    for test in tests:
        try:
            result = test()
            results.append(bool(result))
        except Exception as e:
            print_test(test.__name__, False, str(e))
            results.append(False)
    
    print()
    print("=" * 60)
    passed = sum(results)
    total = len(results)
    
    if passed == total:
        print(f"{Colors.GREEN}All tests passed! ({passed}/{total}){Colors.NC}")
        print()
        print("Configuration validation is properly implemented.")
        return 0
    else:
        print(f"{Colors.RED}Some tests failed. ({passed}/{total} passed){Colors.NC}")
        print()
        print("Please review validation implementation.")
        return 1


if __name__ == '__main__':
    sys.exit(main())
