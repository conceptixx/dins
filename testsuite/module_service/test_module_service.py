#!/usr/bin/env python3
"""
DINS Testsuite - Service Module Tests
=====================================

Tests for DINS Swarm Service Construction per PART 9.

Tests:
- Service descriptor validation
- Directory structure validation
- CLI command availability
- Build mode logic
- Image naming conventions
"""

import os
import sys
import yaml
import subprocess
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))


@dataclass
class ModuleResult:
    """Result of module test execution."""
    module_name: str
    passed: int
    failed: int
    skipped: int
    errors: List[str]
    
    @property
    def success(self) -> bool:
        return self.failed == 0 and len(self.errors) == 0


class ServiceTests:
    """Test cases for DINS service construction."""
    
    def __init__(self, dins_root: str):
        self.dins_root = Path(dins_root)
        self.services_dir = self.dins_root / "services"
        self.config_dir = self.dins_root / "config"
        self.swarm_dir = self.dins_root / "swarm"
        self.secrets_dir = self.dins_root / "system" / "secrets"
        self.cli_dir = self.dins_root / "install" / "_setup.sh" / "cli"
        
        self.passed = 0
        self.failed = 0
        self.skipped = 0
        self.errors = []
    
    def _pass(self, test_name: str):
        """Record a passing test."""
        print(f"  ✓ {test_name}")
        self.passed += 1
    
    def _fail(self, test_name: str, reason: str):
        """Record a failing test."""
        print(f"  ✗ {test_name}: {reason}")
        self.failed += 1
        self.errors.append(f"{test_name}: {reason}")
    
    def _skip(self, test_name: str, reason: str):
        """Record a skipped test."""
        print(f"  ○ {test_name}: SKIPPED ({reason})")
        self.skipped += 1
    
    # =========================================================================
    # DIRECTORY STRUCTURE TESTS
    # =========================================================================
    
    def test_services_directory_exists(self):
        """Test that services/ directory exists."""
        if self.services_dir.exists():
            self._pass("services/ directory exists")
        else:
            self._fail("services/ directory exists", "Directory not found")
    
    def test_services_index_exists(self):
        """Test that services/.index exists."""
        index_file = self.services_dir / ".index"
        if index_file.exists():
            self._pass("services/.index exists")
        else:
            self._fail("services/.index exists", "File not found")
    
    def test_config_directory_exists(self):
        """Test that config/ directory exists."""
        if self.config_dir.exists():
            self._pass("config/ directory exists")
        else:
            self._fail("config/ directory exists", "Directory not found")
    
    def test_swarm_directory_exists(self):
        """Test that swarm/ directory exists."""
        if self.swarm_dir.exists():
            self._pass("swarm/ directory exists")
        else:
            self._fail("swarm/ directory exists", "Directory not found")
    
    def test_secrets_directory_exists(self):
        """Test that system/secrets/ directory exists."""
        if self.secrets_dir.exists():
            self._pass("system/secrets/ directory exists")
        else:
            self._fail("system/secrets/ directory exists", "Directory not found")
    
    # =========================================================================
    # EXAMPLE SERVICE TESTS
    # =========================================================================
    
    def test_example_service_exists(self):
        """Test that _example service template exists."""
        example_dir = self.services_dir / "_example"
        if example_dir.exists():
            self._pass("_example service template exists")
        else:
            self._fail("_example service template exists", "Directory not found")
    
    def test_example_has_service_yaml(self):
        """Test that _example has service.yaml descriptor."""
        service_yaml = self.services_dir / "_example" / "service.yaml"
        if service_yaml.exists():
            self._pass("_example/service.yaml exists")
        else:
            self._fail("_example/service.yaml exists", "File not found")
    
    def test_example_service_yaml_valid(self):
        """Test that _example/service.yaml is valid YAML."""
        service_yaml = self.services_dir / "_example" / "service.yaml"
        if not service_yaml.exists():
            self._skip("_example/service.yaml valid YAML", "File not found")
            return
        
        try:
            with open(service_yaml, 'r') as f:
                data = yaml.safe_load(f)
            
            if isinstance(data, dict):
                self._pass("_example/service.yaml is valid YAML")
            else:
                self._fail("_example/service.yaml is valid YAML", "Not a dictionary")
        except yaml.YAMLError as e:
            self._fail("_example/service.yaml is valid YAML", str(e))
    
    def test_example_has_required_fields(self):
        """Test that _example/service.yaml has required fields per PART 9.2.1."""
        service_yaml = self.services_dir / "_example" / "service.yaml"
        if not service_yaml.exists():
            self._skip("_example has required fields", "File not found")
            return
        
        try:
            with open(service_yaml, 'r') as f:
                data = yaml.safe_load(f)
            
            required_fields = ['name', 'description', 'type', 'image', 'runtime']
            missing = [f for f in required_fields if f not in data]
            
            if not missing:
                self._pass("_example has required fields")
            else:
                self._fail("_example has required fields", f"Missing: {missing}")
        except Exception as e:
            self._fail("_example has required fields", str(e))
    
    def test_example_has_dockerfile(self):
        """Test that _example has Dockerfile for local-build."""
        dockerfile = self.services_dir / "_example" / "Dockerfile"
        if dockerfile.exists():
            self._pass("_example/Dockerfile exists")
        else:
            self._fail("_example/Dockerfile exists", "File not found")
    
    def test_example_has_src_directory(self):
        """Test that _example has src/ directory."""
        src_dir = self.services_dir / "_example" / "src"
        if src_dir.exists():
            self._pass("_example/src/ directory exists")
        else:
            self._fail("_example/src/ directory exists", "Directory not found")
    
    def test_example_has_config_directory(self):
        """Test that _example has config/ directory."""
        config_dir = self.services_dir / "_example" / "config"
        if config_dir.exists():
            self._pass("_example/config/ directory exists")
        else:
            self._fail("_example/config/ directory exists", "Directory not found")
    
    def test_example_has_docs_directory(self):
        """Test that _example has docs/ directory."""
        docs_dir = self.services_dir / "_example" / "docs"
        if docs_dir.exists():
            self._pass("_example/docs/ directory exists")
        else:
            self._fail("_example/docs/ directory exists", "Directory not found")
    
    def test_example_has_tests_directory(self):
        """Test that _example has tests/ directory."""
        tests_dir = self.services_dir / "_example" / "tests"
        if tests_dir.exists():
            self._pass("_example/tests/ directory exists")
        else:
            self._fail("_example/tests/ directory exists", "Directory not found")
    
    # =========================================================================
    # CLI COMMAND TESTS
    # =========================================================================
    
    def test_service_command_exists(self):
        """Test that service.sh command module exists."""
        service_sh = self.cli_dir / "commands" / "service.sh"
        if service_sh.exists():
            self._pass("cli/commands/service.sh exists")
        else:
            self._fail("cli/commands/service.sh exists", "File not found")
    
    def test_service_command_has_entry_function(self):
        """Test that service.sh has cmd_service function."""
        service_sh = self.cli_dir / "commands" / "service.sh"
        if not service_sh.exists():
            self._skip("service.sh has cmd_service", "File not found")
            return
        
        with open(service_sh, 'r') as f:
            content = f.read()
        
        if 'cmd_service()' in content or 'cmd_service ()' in content:
            self._pass("service.sh has cmd_service function")
        else:
            self._fail("service.sh has cmd_service function", "Function not found")
    
    def test_service_command_has_description(self):
        """Test that service.sh has description comment."""
        service_sh = self.cli_dir / "commands" / "service.sh"
        if not service_sh.exists():
            self._skip("service.sh has description", "File not found")
            return
        
        with open(service_sh, 'r') as f:
            content = f.read()
        
        if '# description:' in content:
            self._pass("service.sh has description comment")
        else:
            self._fail("service.sh has description comment", "Comment not found")
    
    # =========================================================================
    # DESCRIPTOR VALIDATION TESTS
    # =========================================================================
    
    def test_no_secrets_in_example_descriptor(self):
        """Test that _example/service.yaml has no actual secret values."""
        service_yaml = self.services_dir / "_example" / "service.yaml"
        if not service_yaml.exists():
            self._skip("No secrets in example descriptor", "File not found")
            return
        
        with open(service_yaml, 'r') as f:
            content = f.read()
        
        # Patterns that might indicate secrets (case-insensitive check)
        secret_indicators = [
            'sk-',          # OpenAI-style keys
            'ghp_',         # GitHub tokens
            'gho_',         # GitHub OAuth
            'xox',          # Slack tokens
            'AKIA',         # AWS access keys
        ]
        
        found_secrets = []
        for indicator in secret_indicators:
            if indicator in content:
                found_secrets.append(indicator)
        
        if not found_secrets:
            self._pass("No obvious secrets in example descriptor")
        else:
            self._fail("No obvious secrets in example descriptor", 
                      f"Possible secrets found: {found_secrets}")
    
    def test_image_mode_valid(self):
        """Test that image.mode is one of the valid options."""
        service_yaml = self.services_dir / "_example" / "service.yaml"
        if not service_yaml.exists():
            self._skip("Image mode valid", "File not found")
            return
        
        try:
            with open(service_yaml, 'r') as f:
                data = yaml.safe_load(f)
            
            mode = data.get('image', {}).get('mode', '')
            valid_modes = ['local-build', 'remote-build', 'prebuilt']
            
            if mode in valid_modes:
                self._pass(f"Image mode valid: {mode}")
            else:
                self._fail("Image mode valid", f"Invalid mode: {mode}")
        except Exception as e:
            self._fail("Image mode valid", str(e))
    
    # =========================================================================
    # RUN ALL TESTS
    # =========================================================================
    
    def run_all(self) -> ModuleResult:
        """Run all tests and return results."""
        print("\n" + "=" * 60)
        print("DINS Service Module Tests")
        print("=" * 60 + "\n")
        
        # Directory structure tests
        print("Directory Structure:")
        self.test_services_directory_exists()
        self.test_services_index_exists()
        self.test_config_directory_exists()
        self.test_swarm_directory_exists()
        self.test_secrets_directory_exists()
        
        # Example service tests
        print("\nExample Service Template:")
        self.test_example_service_exists()
        self.test_example_has_service_yaml()
        self.test_example_service_yaml_valid()
        self.test_example_has_required_fields()
        self.test_example_has_dockerfile()
        self.test_example_has_src_directory()
        self.test_example_has_config_directory()
        self.test_example_has_docs_directory()
        self.test_example_has_tests_directory()
        
        # CLI command tests
        print("\nCLI Commands:")
        self.test_service_command_exists()
        self.test_service_command_has_entry_function()
        self.test_service_command_has_description()
        
        # Descriptor validation
        print("\nDescriptor Validation:")
        self.test_no_secrets_in_example_descriptor()
        self.test_image_mode_valid()
        
        # Summary
        print("\n" + "-" * 60)
        print(f"Results: {self.passed} passed, {self.failed} failed, {self.skipped} skipped")
        print("-" * 60 + "\n")
        
        return ModuleResult(
            module_name="module_service",
            passed=self.passed,
            failed=self.failed,
            skipped=self.skipped,
            errors=self.errors
        )


def run_tests(config: Dict[str, Any]) -> ModuleResult:
    """
    Entry point for testsuite runner.
    
    Args:
        config: Test configuration dictionary with:
            - dins_root: Path to DINS root directory
            - verbose: Enable verbose output
    
    Returns:
        ModuleResult with test outcomes
    """
    dins_root = config.get('dins_root', '/opt/dins')
    
    # Try to find DINS root from script location
    script_path = Path(__file__).resolve()
    for parent in script_path.parents:
        if (parent / 'services').exists() or (parent / 'install').exists():
            dins_root = str(parent)
            break
    
    tests = ServiceTests(dins_root)
    return tests.run_all()


if __name__ == '__main__':
    # Allow running directly for development
    result = run_tests({})
    sys.exit(0 if result.success else 1)
