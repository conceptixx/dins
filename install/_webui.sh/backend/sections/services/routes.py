"""
DINS Web-UI - Services Section Backend
======================================

API routes for managing DINS Swarm services per PART 9.

Endpoints:
- GET /api/services/list - List all services
- GET /api/services/<name> - Get service details
- POST /api/services/<name>/build - Build service image
- POST /api/services/<name>/deploy - Deploy service
- POST /api/services/<name>/remove - Remove service
- GET /api/services/<name>/logs - Get service logs
- GET /api/services/<name>/status - Get deployment status
- GET /api/services/<name>/check - Run diagnostics
"""

import os
import json
import yaml
import subprocess
from pathlib import Path
from flask import Blueprint, jsonify, request

# Create blueprint
bp = Blueprint('services', __name__, url_prefix='/api/services')

# Paths
DINS_ROOT = os.environ.get('DINS_ROOT', '/opt/dins')
SERVICES_DIR = os.path.join(DINS_ROOT, 'services')
CONFIG_DIR = os.path.join(DINS_ROOT, 'config')


def get_service_yaml(name: str) -> dict:
    """Load and parse a service's service.yaml file."""
    service_yaml = os.path.join(SERVICES_DIR, name, 'service.yaml')
    if not os.path.exists(service_yaml):
        return None
    
    try:
        with open(service_yaml, 'r') as f:
            return yaml.safe_load(f)
    except Exception:
        return None


def get_all_services() -> list:
    """Get list of all service names."""
    if not os.path.exists(SERVICES_DIR):
        return []
    
    services = []
    for item in os.listdir(SERVICES_DIR):
        # Skip templates and hidden files
        if item.startswith('_') or item.startswith('.'):
            continue
        
        service_dir = os.path.join(SERVICES_DIR, item)
        if os.path.isdir(service_dir):
            service_yaml = os.path.join(service_dir, 'service.yaml')
            if os.path.exists(service_yaml):
                services.append(item)
    
    return sorted(services)


def get_docker_service_status(name: str) -> dict:
    """Get Docker Swarm service status."""
    swarm_name = f"dins_{name}"
    try:
        # Check if service exists
        result = subprocess.run(
            ['docker', 'service', 'ls', '--format', '{{.Name}}'],
            capture_output=True, text=True, timeout=10
        )
        
        if swarm_name not in result.stdout.split('\n'):
            return {'deployed': False, 'status': 'not_deployed'}
        
        # Get service info
        result = subprocess.run(
            ['docker', 'service', 'inspect', swarm_name, '--format', 
             '{{.Spec.Mode.Replicated.Replicas}}'],
            capture_output=True, text=True, timeout=10
        )
        replicas = result.stdout.strip() if result.returncode == 0 else '0'
        
        # Get running tasks
        result = subprocess.run(
            ['docker', 'service', 'ps', swarm_name, '--filter', 'desired-state=running',
             '--format', '{{.ID}}'],
            capture_output=True, text=True, timeout=10
        )
        running = len([x for x in result.stdout.strip().split('\n') if x])
        
        return {
            'deployed': True,
            'status': 'running' if running > 0 else 'stopped',
            'replicas': replicas,
            'running_tasks': running
        }
    except Exception as e:
        return {'deployed': False, 'status': 'unknown', 'error': str(e)}


@bp.route('/list')
def list_services():
    """List all defined services."""
    services = []
    
    for name in get_all_services():
        descriptor = get_service_yaml(name)
        if descriptor:
            docker_status = get_docker_service_status(name)
            services.append({
                'name': name,
                'description': descriptor.get('description', ''),
                'type': descriptor.get('type', 'unknown'),
                'version': descriptor.get('version', 'unknown'),
                'image_mode': descriptor.get('image', {}).get('mode', 'unknown'),
                'deployed': docker_status.get('deployed', False),
                'status': docker_status.get('status', 'unknown')
            })
    
    return jsonify({
        'success': True,
        'services': services,
        'count': len(services)
    })


@bp.route('/<name>')
def get_service(name: str):
    """Get service details."""
    descriptor = get_service_yaml(name)
    if not descriptor:
        return jsonify({
            'success': False,
            'error': f'Service not found: {name}'
        }), 404
    
    docker_status = get_docker_service_status(name)
    
    # Get directory contents
    service_dir = os.path.join(SERVICES_DIR, name)
    contents = []
    if os.path.exists(service_dir):
        for item in os.listdir(service_dir):
            item_path = os.path.join(service_dir, item)
            contents.append({
                'name': item,
                'type': 'directory' if os.path.isdir(item_path) else 'file'
            })
    
    return jsonify({
        'success': True,
        'service': {
            'name': name,
            'descriptor': descriptor,
            'docker_status': docker_status,
            'directory_contents': contents,
            'path': service_dir
        }
    })


@bp.route('/<name>/build', methods=['POST'])
def build_service(name: str):
    """Build service image."""
    descriptor = get_service_yaml(name)
    if not descriptor:
        return jsonify({
            'success': False,
            'error': f'Service not found: {name}'
        }), 404
    
    mode = request.json.get('mode') if request.is_json else None
    if not mode:
        mode = descriptor.get('image', {}).get('mode', 'local-build')
    
    try:
        result = subprocess.run(
            ['dinser', 'service', 'build', name, '--mode', mode],
            capture_output=True, text=True, timeout=300
        )
        
        return jsonify({
            'success': result.returncode == 0,
            'output': result.stdout,
            'error': result.stderr if result.returncode != 0 else None
        })
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'error': 'Build timed out after 5 minutes'
        }), 500
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@bp.route('/<name>/deploy', methods=['POST'])
def deploy_service(name: str):
    """Deploy service to swarm."""
    descriptor = get_service_yaml(name)
    if not descriptor:
        return jsonify({
            'success': False,
            'error': f'Service not found: {name}'
        }), 404
    
    try:
        result = subprocess.run(
            ['dinser', 'service', 'deploy', name],
            capture_output=True, text=True, timeout=120
        )
        
        return jsonify({
            'success': result.returncode == 0,
            'output': result.stdout,
            'error': result.stderr if result.returncode != 0 else None
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@bp.route('/<name>/remove', methods=['POST'])
def remove_service(name: str):
    """Remove service from swarm."""
    force = request.json.get('force', False) if request.is_json else False
    
    try:
        cmd = ['dinser', 'service', 'remove', name]
        if force:
            cmd.append('--force')
        
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=60,
            input='y\n' if not force else None
        )
        
        return jsonify({
            'success': result.returncode == 0,
            'output': result.stdout,
            'error': result.stderr if result.returncode != 0 else None
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@bp.route('/<name>/logs')
def get_service_logs(name: str):
    """Get service logs."""
    tail = request.args.get('tail', '100')
    
    swarm_name = f"dins_{name}"
    try:
        result = subprocess.run(
            ['docker', 'service', 'logs', '--tail', tail, swarm_name],
            capture_output=True, text=True, timeout=30
        )
        
        return jsonify({
            'success': True,
            'logs': result.stdout + result.stderr
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@bp.route('/<name>/status')
def get_service_status(name: str):
    """Get service deployment status."""
    docker_status = get_docker_service_status(name)
    descriptor = get_service_yaml(name)
    
    return jsonify({
        'success': True,
        'name': name,
        'defined': descriptor is not None,
        'docker': docker_status
    })


@bp.route('/<name>/check')
def check_service(name: str):
    """Run service diagnostics."""
    checks = []
    
    # Check 1: Service definition
    descriptor = get_service_yaml(name)
    checks.append({
        'name': 'Service Definition',
        'passed': descriptor is not None,
        'message': 'service.yaml found' if descriptor else 'service.yaml not found'
    })
    
    # Check 2: Docker available
    try:
        result = subprocess.run(['docker', 'info'], capture_output=True, timeout=10)
        docker_ok = result.returncode == 0
    except:
        docker_ok = False
    
    checks.append({
        'name': 'Docker',
        'passed': docker_ok,
        'message': 'Docker is running' if docker_ok else 'Docker not available'
    })
    
    # Check 3: Swarm active
    try:
        result = subprocess.run(['docker', 'info'], capture_output=True, text=True, timeout=10)
        swarm_ok = 'Swarm: active' in result.stdout
    except:
        swarm_ok = False
    
    checks.append({
        'name': 'Docker Swarm',
        'passed': swarm_ok,
        'message': 'Swarm is active' if swarm_ok else 'Swarm not active'
    })
    
    # Check 4: Image exists
    if descriptor:
        version = descriptor.get('version', 'latest')
        image_tag = f"dins/{name}:{version}"
        try:
            result = subprocess.run(
                ['docker', 'image', 'inspect', image_tag],
                capture_output=True, timeout=10
            )
            image_ok = result.returncode == 0
        except:
            image_ok = False
        
        checks.append({
            'name': 'Image',
            'passed': image_ok,
            'message': f'Image exists: {image_tag}' if image_ok else f'Image not found: {image_tag}'
        })
    
    # Check 5: Deployment
    docker_status = get_docker_service_status(name)
    checks.append({
        'name': 'Deployment',
        'passed': docker_status.get('deployed', False),
        'message': docker_status.get('status', 'unknown')
    })
    
    passed = sum(1 for c in checks if c['passed'])
    failed = len(checks) - passed
    
    return jsonify({
        'success': True,
        'name': name,
        'checks': checks,
        'summary': {
            'passed': passed,
            'failed': failed,
            'total': len(checks)
        }
    })


# Register blueprint function (called by app.py)
def register(app):
    """Register the services blueprint with the Flask app."""
    app.register_blueprint(bp)
