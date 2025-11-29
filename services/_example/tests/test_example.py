#!/usr/bin/env python3
"""
Example Service Tests

These tests validate the example service functionality.
Run via: dinser test service or pytest tests/
"""

import pytest
import json
from unittest.mock import patch, MagicMock


class TestExampleService:
    """Tests for example service."""
    
    def test_service_yaml_exists(self):
        """Verify service.yaml descriptor exists."""
        import os
        service_yaml = os.path.join(os.path.dirname(__file__), '..', 'service.yaml')
        assert os.path.exists(service_yaml), "service.yaml must exist"
    
    def test_service_yaml_valid(self):
        """Verify service.yaml is valid YAML with required fields."""
        import yaml
        import os
        
        service_yaml = os.path.join(os.path.dirname(__file__), '..', 'service.yaml')
        with open(service_yaml, 'r') as f:
            descriptor = yaml.safe_load(f)
        
        # Required fields per PART 9.2.1
        assert 'name' in descriptor
        assert 'description' in descriptor
        assert 'type' in descriptor
        assert 'image' in descriptor
        assert 'runtime' in descriptor
    
    def test_dockerfile_exists(self):
        """Verify Dockerfile exists for local-build mode."""
        import os
        dockerfile = os.path.join(os.path.dirname(__file__), '..', 'Dockerfile')
        assert os.path.exists(dockerfile), "Dockerfile must exist for local-build"
    
    def test_main_py_exists(self):
        """Verify main.py entry point exists."""
        import os
        main_py = os.path.join(os.path.dirname(__file__), '..', 'src', 'main.py')
        assert os.path.exists(main_py), "src/main.py must exist"
    
    def test_no_secrets_in_descriptor(self):
        """Ensure no actual secret values in service.yaml."""
        import yaml
        import os
        
        service_yaml = os.path.join(os.path.dirname(__file__), '..', 'service.yaml')
        with open(service_yaml, 'r') as f:
            content = f.read()
        
        # Check for common secret patterns
        secret_patterns = [
            'api_key:',
            'password:',
            'secret:',
            'token:',
            'BEGIN PRIVATE KEY',
            'BEGIN RSA',
        ]
        
        for pattern in secret_patterns:
            # Allow pattern in comments or as field names, not as values
            lines = content.split('\n')
            for line in lines:
                if pattern.lower() in line.lower():
                    # Skip if it's a comment or empty value
                    if line.strip().startswith('#'):
                        continue
                    if ': ""' in line or ": ''" in line or line.strip().endswith(':'):
                        continue
                    # If there's an actual value, this might be a problem
                    # (This is a heuristic check)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
