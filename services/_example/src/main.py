#!/usr/bin/env python3
"""
Example DINS Service - Template Main Entry Point

This is a minimal example showing the expected structure
for a DINS-managed service.
"""

import os
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

# Read configuration from environment (injected by DINS/DINSER)
LOG_LEVEL = os.getenv('LOG_LEVEL', 'info')
APP_MODE = os.getenv('APP_MODE', 'development')
SERVICE_PORT = int(os.getenv('SERVICE_PORT', '8080'))


class ServiceHandler(BaseHTTPRequestHandler):
    """Simple HTTP handler for example service."""
    
    def do_GET(self):
        """Handle GET requests."""
        if self.path == '/health':
            self._respond(200, {'status': 'healthy', 'service': 'example'})
        elif self.path == '/status':
            self._respond(200, {
                'status': 'running',
                'mode': APP_MODE,
                'log_level': LOG_LEVEL
            })
        elif self.path == '/':
            self._respond(200, {
                'message': 'DINS Example Service',
                'version': '1.0.0',
                'endpoints': ['/health', '/status']
            })
        else:
            self._respond(404, {'error': 'Not found'})
    
    def _respond(self, status_code: int, data: dict):
        """Send JSON response."""
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def log_message(self, format, *args):
        """Custom log format."""
        if LOG_LEVEL in ('debug', 'info'):
            print(f"[{self.log_date_time_string()}] {format % args}")


def main():
    """Start the example service."""
    print(f"Starting DINS Example Service on port {SERVICE_PORT}")
    print(f"Mode: {APP_MODE}, Log Level: {LOG_LEVEL}")
    
    server = HTTPServer(('0.0.0.0', SERVICE_PORT), ServiceHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()


if __name__ == '__main__':
    main()
