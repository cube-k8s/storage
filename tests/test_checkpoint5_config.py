#!/usr/bin/env python3
"""
Checkpoint 5 Configuration Validation Tests

These tests verify that the Ansible configuration files are properly structured
and contain the required settings for the base infrastructure.

Run with: python3 tests/test_checkpoint5_config.py
"""

import os
import sys
import yaml
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


def test_ansible_cfg_exists():
    """Test that ansible.cfg exists"""
    return print_test(
        "ansible.cfg exists",
        Path("ansible.cfg").exists(),
        "ansible.cfg file not found"
    )


def test_inventory_exists():
    """Test that inventory file exists"""
    return print_test(
        "inventory/hosts.yml exists",
        Path("inventory/hosts.yml").exists(),
        "inventory/hosts.yml file not found"
    )


def test_playbook_exists():
    """Test that main playbook exists"""
    return print_test(
        "playbooks/site.yml exists",
        Path("playbooks/site.yml").exists(),
        "playbooks/site.yml file not found"
    )


def test_group_vars_exists():
    """Test that group_vars file exists"""
    return print_test(
        "group_vars/fileservers.yml exists",
        Path("group_vars/fileservers.yml").exists(),
        "group_vars/fileservers.yml file not found"
    )


def test_inventory_structure():
    """Test that inventory has correct structure"""
    try:
        with open("inventory/hosts.yml", 'r') as f:
            inventory = yaml.safe_load(f)
        
        has_fileservers = 'all' in inventory and 'children' in inventory['all'] and 'fileservers' in inventory['all']['children']
        return print_test(
            "Inventory has fileservers group",
            has_fileservers,
            "Inventory missing 'fileservers' group under 'all.children'"
        )
    except Exception as e:
        return print_test("Inventory structure", False, str(e))


def test_playbook_structure():
    """Test that playbook has correct structure"""
    try:
        with open("playbooks/site.yml", 'r') as f:
            playbook = yaml.safe_load(f)
        
        if not isinstance(playbook, list) or len(playbook) == 0:
            return print_test("Playbook structure", False, "Playbook should be a list with at least one play")
        
        play = playbook[0]
        has_hosts = 'hosts' in play and play['hosts'] == 'fileservers'
        has_roles = 'roles' in play and isinstance(play['roles'], list)
        
        return print_test(
            "Playbook targets fileservers with roles",
            has_hosts and has_roles,
            "Playbook should target 'fileservers' and include roles"
        )
    except Exception as e:
        return print_test("Playbook structure", False, str(e))


def test_playbook_includes_required_roles():
    """Test that playbook includes required roles for checkpoint 5"""
    try:
        with open("playbooks/site.yml", 'r') as f:
            playbook = yaml.safe_load(f)
        
        play = playbook[0]
        roles = []
        for role in play.get('roles', []):
            if isinstance(role, dict):
                roles.append(role.get('role', ''))
            else:
                roles.append(role)
        
        required_roles = ['common', 'kerberos-client', 'shares']
        has_all_roles = all(role in roles for role in required_roles)
        
        return print_test(
            "Playbook includes required roles (common, kerberos-client, shares)",
            has_all_roles,
            f"Missing roles. Found: {roles}, Required: {required_roles}"
        )
    except Exception as e:
        return print_test("Playbook roles", False, str(e))


def test_group_vars_has_kerberos_config():
    """Test that group_vars has Kerberos configuration"""
    try:
        with open("group_vars/fileservers.yml", 'r') as f:
            vars_data = yaml.safe_load(f)
        
        has_realm = 'krb5_realm' in vars_data and vars_data['krb5_realm']
        has_kdc = 'krb5_kdc' in vars_data and vars_data['krb5_kdc']
        
        return print_test(
            "group_vars has Kerberos configuration (realm, KDC)",
            has_realm and has_kdc,
            "Missing krb5_realm or krb5_kdc in group_vars"
        )
    except Exception as e:
        return print_test("Kerberos configuration", False, str(e))


def test_group_vars_has_shares():
    """Test that group_vars has shares defined"""
    try:
        with open("group_vars/fileservers.yml", 'r') as f:
            vars_data = yaml.safe_load(f)
        
        has_shares = 'shares' in vars_data and isinstance(vars_data['shares'], list) and len(vars_data['shares']) > 0
        
        if has_shares:
            # Verify share structure
            share = vars_data['shares'][0]
            has_path = 'path' in share
            has_owner = 'owner' in share
            has_group = 'group' in share
            has_mode = 'mode' in share
            
            return print_test(
                "group_vars has shares with required fields",
                has_path and has_owner and has_group and has_mode,
                "Share missing required fields (path, owner, group, mode)"
            )
        else:
            return print_test(
                "group_vars has shares defined",
                False,
                "No shares defined in group_vars"
            )
    except Exception as e:
        return print_test("Shares configuration", False, str(e))


def test_role_directories_exist():
    """Test that required role directories exist"""
    required_roles = ['common', 'kerberos-client', 'shares']
    all_exist = True
    
    for role in required_roles:
        role_path = Path(f"roles/{role}")
        exists = role_path.exists() and role_path.is_dir()
        if not exists:
            all_exist = False
        print_test(f"Role directory 'roles/{role}' exists", exists, f"Directory not found" if not exists else "")
    
    return all_exist


def test_role_tasks_exist():
    """Test that required roles have tasks/main.yml"""
    required_roles = ['common', 'kerberos-client', 'shares']
    all_exist = True
    
    for role in required_roles:
        tasks_file = Path(f"roles/{role}/tasks/main.yml")
        exists = tasks_file.exists()
        if not exists:
            all_exist = False
        print_test(f"Role '{role}' has tasks/main.yml", exists, f"File not found" if not exists else "")
    
    return all_exist


def test_kerberos_template_exists():
    """Test that Kerberos template exists"""
    return print_test(
        "Kerberos template (krb5.conf.j2) exists",
        Path("roles/kerberos-client/templates/krb5.conf.j2").exists(),
        "Template file not found"
    )


def test_kerberos_template_content():
    """Test that Kerberos template has required sections"""
    try:
        with open("roles/kerberos-client/templates/krb5.conf.j2", 'r') as f:
            content = f.read()
        
        has_libdefaults = '[libdefaults]' in content
        has_realms = '[realms]' in content
        has_domain_realm = '[domain_realm]' in content
        has_realm_var = '{{ krb5_realm }}' in content
        has_kdc_var = '{{ krb5_kdc }}' in content
        
        all_present = has_libdefaults and has_realms and has_domain_realm and has_realm_var and has_kdc_var
        
        return print_test(
            "Kerberos template has required sections and variables",
            all_present,
            "Template missing required sections or variables"
        )
    except Exception as e:
        return print_test("Kerberos template content", False, str(e))


def main():
    """Run all tests"""
    print("=" * 60)
    print("Checkpoint 5: Configuration Validation Tests")
    print("=" * 60)
    print()
    
    # Change to project root if running from tests directory
    if Path.cwd().name == 'tests':
        os.chdir('..')
    
    tests = [
        test_ansible_cfg_exists,
        test_inventory_exists,
        test_playbook_exists,
        test_group_vars_exists,
        test_inventory_structure,
        test_playbook_structure,
        test_playbook_includes_required_roles,
        test_group_vars_has_kerberos_config,
        test_group_vars_has_shares,
        test_role_directories_exist,
        test_role_tasks_exist,
        test_kerberos_template_exists,
        test_kerberos_template_content,
    ]
    
    print("Running configuration tests...")
    print()
    
    results = []
    for test in tests:
        try:
            result = test()
            # Ensure result is boolean
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
        print("Configuration is valid. Ready to deploy to test system.")
        return 0
    else:
        print(f"{Colors.RED}Some tests failed. ({passed}/{total} passed){Colors.NC}")
        print()
        print("Please fix configuration issues before deploying.")
        return 1


if __name__ == '__main__':
    sys.exit(main())
