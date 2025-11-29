/**
 * DINS Web-UI - Services Section JavaScript
 * Handles Swarm service management per PART 9
 */

const ServicesPage = {
    currentService: null,
    
    /**
     * Initialize the page
     */
    init() {
        this.refresh();
    },
    
    /**
     * Refresh the services list
     */
    async refresh() {
        const loading = document.getElementById('services-loading');
        const error = document.getElementById('services-error');
        const table = document.getElementById('services-table');
        const empty = document.getElementById('services-empty');
        const tbody = document.getElementById('services-body');
        
        loading.classList.remove('hidden');
        error.classList.add('hidden');
        table.classList.add('hidden');
        empty.classList.add('hidden');
        
        try {
            const response = await fetch('/api/services/list');
            const data = await response.json();
            
            loading.classList.add('hidden');
            
            if (!data.success) {
                error.textContent = data.error || 'Failed to load services';
                error.classList.remove('hidden');
                return;
            }
            
            if (data.services.length === 0) {
                empty.classList.remove('hidden');
                return;
            }
            
            tbody.innerHTML = data.services.map(service => `
                <tr>
                    <td>
                        <a href="#" onclick="ServicesPage.showDetails('${service.name}'); return false;">
                            ${service.name}
                        </a>
                    </td>
                    <td>${service.type}</td>
                    <td>${service.version}</td>
                    <td>${service.image_mode}</td>
                    <td>
                        <span class="status-badge status-${service.status}">
                            ${service.status}
                        </span>
                    </td>
                    <td>
                        <div class="btn-group">
                            <button class="btn btn-sm" onclick="ServicesPage.showBuild('${service.name}')">
                                Build
                            </button>
                            <button class="btn btn-sm btn-primary" onclick="ServicesPage.deploy('${service.name}')">
                                Deploy
                            </button>
                            <button class="btn btn-sm" onclick="ServicesPage.showLogs('${service.name}')"
                                    ${!service.deployed ? 'disabled' : ''}>
                                Logs
                            </button>
                            <button class="btn btn-sm" onclick="ServicesPage.showCheck('${service.name}')">
                                Check
                            </button>
                        </div>
                    </td>
                </tr>
            `).join('');
            
            table.classList.remove('hidden');
            
        } catch (err) {
            loading.classList.add('hidden');
            error.textContent = 'Network error: ' + err.message;
            error.classList.remove('hidden');
        }
    },
    
    /**
     * Show service details modal
     */
    async showDetails(name) {
        this.currentService = name;
        const modal = document.getElementById('service-details-modal');
        const title = document.getElementById('detail-service-name');
        const content = document.getElementById('service-details-content');
        
        title.textContent = name;
        content.innerHTML = '<div class="loading">Loading...</div>';
        modal.classList.remove('hidden');
        
        try {
            const response = await fetch(`/api/services/${name}`);
            const data = await response.json();
            
            if (!data.success) {
                content.innerHTML = `<div class="error">${data.error}</div>`;
                return;
            }
            
            const service = data.service;
            const descriptor = service.descriptor;
            
            content.innerHTML = `
                <div class="detail-section">
                    <h4>Basic Info</h4>
                    <dl>
                        <dt>Name</dt><dd>${descriptor.name}</dd>
                        <dt>Description</dt><dd>${descriptor.description || 'N/A'}</dd>
                        <dt>Type</dt><dd>${descriptor.type}</dd>
                        <dt>Version</dt><dd>${descriptor.version}</dd>
                    </dl>
                </div>
                
                <div class="detail-section">
                    <h4>Image</h4>
                    <dl>
                        <dt>Mode</dt><dd>${descriptor.image?.mode || 'unknown'}</dd>
                    </dl>
                </div>
                
                <div class="detail-section">
                    <h4>Runtime</h4>
                    <dl>
                        <dt>Replicas</dt><dd>${descriptor.runtime?.replicas || 1}</dd>
                        <dt>Networks</dt><dd>${(descriptor.runtime?.networks || []).join(', ') || 'default'}</dd>
                    </dl>
                </div>
                
                <div class="detail-section">
                    <h4>Deployment Status</h4>
                    <dl>
                        <dt>Deployed</dt><dd>${service.docker_status.deployed ? 'Yes' : 'No'}</dd>
                        <dt>Status</dt><dd>${service.docker_status.status}</dd>
                    </dl>
                </div>
                
                <div class="detail-section">
                    <h4>Directory Contents</h4>
                    <ul>
                        ${service.directory_contents.map(item => 
                            `<li>${item.type === 'directory' ? '📁' : '📄'} ${item.name}</li>`
                        ).join('')}
                    </ul>
                </div>
            `;
            
        } catch (err) {
            content.innerHTML = `<div class="error">Error: ${err.message}</div>`;
        }
    },
    
    closeDetails() {
        document.getElementById('service-details-modal').classList.add('hidden');
    },
    
    /**
     * Show build modal
     */
    showBuild(name) {
        this.currentService = name;
        document.getElementById('build-service-name').textContent = name;
        document.getElementById('build-output').classList.add('hidden');
        document.getElementById('build-btn').disabled = false;
        document.getElementById('build-modal').classList.remove('hidden');
    },
    
    closeBuild() {
        document.getElementById('build-modal').classList.add('hidden');
    },
    
    /**
     * Execute build
     */
    async executeBuild() {
        const name = this.currentService;
        const mode = document.getElementById('build-mode').value;
        const output = document.getElementById('build-output');
        const outputText = document.getElementById('build-output-text');
        const btn = document.getElementById('build-btn');
        
        btn.disabled = true;
        btn.textContent = 'Building...';
        output.classList.remove('hidden');
        outputText.textContent = 'Starting build...\n';
        
        try {
            const response = await fetch(`/api/services/${name}/build`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ mode })
            });
            const data = await response.json();
            
            outputText.textContent = data.output || data.error || 'No output';
            btn.textContent = data.success ? 'Build Complete' : 'Build Failed';
            
            if (data.success) {
                setTimeout(() => this.refresh(), 1000);
            }
            
        } catch (err) {
            outputText.textContent = 'Error: ' + err.message;
            btn.textContent = 'Build Failed';
        }
    },
    
    /**
     * Deploy service
     */
    async deploy(name) {
        if (!confirm(`Deploy service "${name}"?`)) {
            return;
        }
        
        try {
            const response = await fetch(`/api/services/${name}/deploy`, {
                method: 'POST'
            });
            const data = await response.json();
            
            if (data.success) {
                alert('Deployment started successfully');
                this.refresh();
            } else {
                alert('Deployment failed: ' + data.error);
            }
            
        } catch (err) {
            alert('Error: ' + err.message);
        }
    },
    
    /**
     * Show logs modal
     */
    async showLogs(name) {
        this.currentService = name;
        document.getElementById('logs-service-name').textContent = name;
        document.getElementById('logs-text').textContent = 'Loading...';
        document.getElementById('logs-modal').classList.remove('hidden');
        
        await this.refreshLogs();
    },
    
    closeLogs() {
        document.getElementById('logs-modal').classList.add('hidden');
    },
    
    async refreshLogs() {
        const name = this.currentService;
        const logsText = document.getElementById('logs-text');
        
        try {
            const response = await fetch(`/api/services/${name}/logs?tail=200`);
            const data = await response.json();
            
            logsText.textContent = data.logs || 'No logs available';
            
        } catch (err) {
            logsText.textContent = 'Error: ' + err.message;
        }
    },
    
    /**
     * Show diagnostics modal
     */
    async showCheck(name) {
        this.currentService = name;
        document.getElementById('check-service-name').textContent = name;
        document.getElementById('check-content').innerHTML = '<div class="loading">Running diagnostics...</div>';
        document.getElementById('check-modal').classList.remove('hidden');
        
        try {
            const response = await fetch(`/api/services/${name}/check`);
            const data = await response.json();
            
            const content = document.getElementById('check-content');
            
            if (!data.success) {
                content.innerHTML = `<div class="error">${data.error}</div>`;
                return;
            }
            
            content.innerHTML = `
                ${data.checks.map(check => `
                    <div class="check-item ${check.passed ? 'check-passed' : 'check-failed'}">
                        <span class="check-icon">${check.passed ? '✓' : '✗'}</span>
                        <div>
                            <strong>${check.name}</strong>
                            <p>${check.message}</p>
                        </div>
                    </div>
                `).join('')}
                
                <div class="check-summary" style="margin-top: 16px; padding-top: 16px; border-top: 1px solid #ddd;">
                    <strong>Summary:</strong> 
                    ${data.summary.passed} passed, ${data.summary.failed} failed
                </div>
            `;
            
        } catch (err) {
            document.getElementById('check-content').innerHTML = 
                `<div class="error">Error: ${err.message}</div>`;
        }
    },
    
    closeCheck() {
        document.getElementById('check-modal').classList.add('hidden');
    }
};

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => ServicesPage.init());
