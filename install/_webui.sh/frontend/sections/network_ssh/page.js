/**
 * Network & SSH Discovery Section JavaScript
 */

async function init_network_ssh() {
    console.log('Initializing Network & SSH section');
    await loadPermissions();
    await loadScanRanges();
    await refreshNodes();
    setupFormHandlers();
}

async function loadPermissions() {
    try {
        const perms = await DINS.API.get('/network/permissions');
        document.getElementById('allow-network-scan').checked = perms.allow_network_scan;
        document.getElementById('allow-ssh-scan').checked = perms.allow_ssh_scan;
        updateScanButtons(perms);
    } catch (error) {
        console.error('Failed to load permissions:', error);
    }
}

async function loadScanRanges() {
    try {
        const data = await DINS.API.get('/network/scan-ranges');
        document.getElementById('scan-ranges').value = data.scan_ranges.join('\n');
    } catch (error) {
        console.error('Failed to load scan ranges:', error);
    }
}

async function refreshNodes() {
    try {
        const nodes = await DINS.API.get('/discovery/nodes');
        renderNodesTable(nodes);
    } catch (error) {
        console.error('Failed to load nodes:', error);
    }
}

function renderNodesTable(nodes) {
    const tbody = document.getElementById('nodes-tbody');
    
    if (!nodes || nodes.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="5" style="text-align: center; color: var(--text-muted); padding: 2rem;">
                    No nodes discovered yet. Run a scan to find devices.
                </td>
            </tr>
        `;
        return;
    }
    
    tbody.innerHTML = nodes.map(node => `
        <tr>
            <td>${DINS.Utils.escapeHtml(node.node_id || 'N/A')}</td>
            <td>${DINS.Utils.escapeHtml(node.hostname || 'Unknown')}</td>
            <td>${DINS.Utils.escapeHtml(node.ip || 'N/A')}</td>
            <td>
                <span class="badge ${node.reachable_via_ssh ? 'badge-success' : 'badge-warning'}">
                    ${node.reachable_via_ssh ? 'Yes' : 'No'}
                </span>
            </td>
            <td>${node.role || 'worker'}</td>
        </tr>
    `).join('');
}

function updateScanButtons(perms) {
    document.getElementById('network-scan-btn').disabled = !perms.allow_network_scan;
    document.getElementById('ssh-scan-btn').disabled = !perms.allow_ssh_scan;
}

function setupFormHandlers() {
    // Permissions form
    document.getElementById('permissions-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const data = {
            allow_network_scan: document.getElementById('allow-network-scan').checked,
            allow_ssh_scan: document.getElementById('allow-ssh-scan').checked
        };
        
        try {
            await DINS.API.post('/network/permissions', data);
            DINS.Toast.success('Permissions saved');
            updateScanButtons(data);
        } catch (error) {
            DINS.Toast.error(error.message);
        }
    });
    
    // SSH password form
    document.getElementById('ssh-password-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const password = document.getElementById('pi-password').value;
        
        if (!password) {
            DINS.Toast.warning('Please enter a password');
            return;
        }
        
        try {
            await DINS.API.post('/network/ssh-password', { password });
            DINS.Toast.success('SSH password saved securely');
            document.getElementById('pi-password').value = '';
        } catch (error) {
            DINS.Toast.error(error.message);
        }
    });
    
    // Scan ranges form
    document.getElementById('scan-ranges-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const rangesText = document.getElementById('scan-ranges').value;
        const ranges = rangesText.split('\n').map(r => r.trim()).filter(r => r);
        
        try {
            await DINS.API.post('/network/scan-ranges', { scan_ranges: ranges });
            DINS.Toast.success('Scan ranges saved');
        } catch (error) {
            DINS.Toast.error(error.message);
        }
    });
}

async function runNetworkScan() {
    const btn = document.getElementById('network-scan-btn');
    DINS.Loading.button(btn, true);
    
    try {
        const result = await DINS.API.post('/network/scan');
        showScanResults('Network Scan', result);
        await refreshNodes();
    } catch (error) {
        DINS.Toast.error(error.message);
    } finally {
        DINS.Loading.button(btn, false);
    }
}

async function runSSHScan() {
    const btn = document.getElementById('ssh-scan-btn');
    DINS.Loading.button(btn, true);
    
    try {
        const result = await DINS.API.post('/network/ssh-scan');
        showScanResults('SSH Scan', result);
        await refreshNodes();
    } catch (error) {
        DINS.Toast.error(error.message);
    } finally {
        DINS.Loading.button(btn, false);
    }
}

function showScanResults(title, result) {
    const resultsDiv = document.getElementById('scan-results');
    const contentDiv = document.getElementById('results-content');
    
    resultsDiv.style.display = 'block';
    contentDiv.innerHTML = `
        <div class="alert ${result.status === 'completed' ? 'alert-success' : 'alert-warning'}">
            <strong>${title} ${result.status}</strong><br>
            ${result.hosts_found !== undefined ? `Hosts found: ${result.hosts_found}` : ''}
            ${result.nodes_found !== undefined ? `Nodes found: ${result.nodes_found}` : ''}
        </div>
    `;
}

window.init_network_ssh = init_network_ssh;
