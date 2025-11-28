/**
 * Cluster & Swarm Setup Section JavaScript
 */

let localInfo = null;
let discoveredNodes = [];

async function init_cluster_swarm() {
    console.log('Initializing Cluster & Swarm section');
    await loadLocalInfo();
    await loadDiscoveredNodes();
    await refreshSwarmStatus();
}

async function loadLocalInfo() {
    try {
        localInfo = await DINS.API.get('/cluster/local-info');
        
        document.getElementById('current-hostname').textContent = localInfo.current_hostname;
        document.getElementById('planned-hostname').textContent = localInfo.planned_hostname;
        document.getElementById('ip-addresses').textContent = localInfo.ip_addresses.join(', ') || 'Unknown';
        
        if (localInfo.is_dins_main) {
            document.getElementById('local-role').textContent = 'dins-main';
            document.getElementById('local-role').className = 'badge badge-success';
            document.getElementById('rename-btn').disabled = true;
            document.getElementById('rename-btn').textContent = 'Already dins-main';
        }
    } catch (error) {
        console.error('Failed to load local info:', error);
        DINS.Toast.error('Failed to load local host information');
    }
}

async function loadDiscoveredNodes() {
    try {
        const nodes = await DINS.API.get('/discovery/nodes');
        discoveredNodes = nodes;
        renderNodesTable();
    } catch (error) {
        console.error('Failed to load nodes:', error);
    }
}

function renderNodesTable() {
    const tbody = document.getElementById('nodes-tbody');
    
    if (discoveredNodes.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="text-center">No nodes discovered yet</td></tr>';
        document.getElementById('install-nodes-btn').disabled = true;
        return;
    }
    
    tbody.innerHTML = discoveredNodes.map(node => `
        <tr>
            <td>${DINS.Utils.escapeHtml(node.hostname || 'Unknown')}</td>
            <td>${DINS.Utils.escapeHtml(node.ip)}</td>
            <td>${node.final_hostname || '<span class="text-muted">Not assigned</span>'}</td>
            <td>
                <span class="badge ${node.reachable_via_ssh ? 'badge-success' : 'badge-warning'}">
                    ${node.reachable_via_ssh ? 'Reachable' : 'Unknown'}
                </span>
            </td>
            <td>
                <input type="checkbox" class="node-select" data-node-id="${node.node_id}" 
                       ${node.selected ? 'checked' : ''}>
            </td>
        </tr>
    `).join('');
    
    // Enable install button if any nodes exist
    document.getElementById('install-nodes-btn').disabled = false;
}

async function renameLocalHost() {
    const confirmed = await DINS.Dialog.confirm(
        'This will rename this machine to "dins-main". A reboot may be required. Continue?',
        'Rename Host'
    );
    
    if (!confirmed) return;
    
    const btn = document.getElementById('rename-btn');
    DINS.Loading.button(btn, true);
    
    try {
        const result = await DINS.API.post('/cluster/rename-local', {
            desired_hostname: 'dins-main'
        });
        
        if (result.status === 'changed') {
            DINS.Toast.success('Hostname changed successfully');
            document.getElementById('rename-warning').style.display = 'block';
        } else {
            DINS.Toast.info('Hostname is already dins-main');
        }
        
        await loadLocalInfo();
    } catch (error) {
        DINS.Toast.error(error.message);
    } finally {
        DINS.Loading.button(btn, false);
    }
}

async function planNodeHostnames() {
    const selectedNodes = getSelectedNodes();
    
    if (selectedNodes.length === 0) {
        DINS.Toast.warning('Please select at least one node');
        return;
    }
    
    try {
        const planned = await DINS.API.post('/cluster/plan-node-hostnames', {
            nodes: selectedNodes
        });
        
        // Update local data
        planned.forEach(p => {
            const node = discoveredNodes.find(n => n.node_id === p.node_id);
            if (node) {
                node.final_hostname = p.final_hostname;
            }
        });
        
        renderNodesTable();
        DINS.Toast.success('Hostnames planned successfully');
    } catch (error) {
        DINS.Toast.error(error.message);
    }
}

function getSelectedNodes() {
    const checkboxes = document.querySelectorAll('.node-select:checked');
    return Array.from(checkboxes).map(cb => {
        const nodeId = cb.dataset.nodeId;
        return discoveredNodes.find(n => n.node_id === nodeId);
    }).filter(Boolean);
}

async function installNodes() {
    const selectedNodes = getSelectedNodes();
    
    if (selectedNodes.length === 0) {
        DINS.Toast.warning('Please select nodes to install');
        return;
    }
    
    const confirmed = await DINS.Dialog.confirm(
        `Install DINS on ${selectedNodes.length} node(s)? This may take several minutes.`,
        'Install DINS'
    );
    
    if (!confirmed) return;
    
    const btn = document.getElementById('install-nodes-btn');
    DINS.Loading.button(btn, true);
    
    const progressDiv = document.getElementById('install-progress');
    const progressList = document.getElementById('progress-list');
    progressDiv.style.display = 'block';
    
    // Initialize progress display
    progressList.innerHTML = selectedNodes.map(node => `
        <div class="progress-item" id="progress-${node.node_id}">
            <span>${node.hostname || node.ip}</span>
            <span class="badge badge-info">Pending</span>
        </div>
    `).join('');
    
    try {
        const results = await DINS.API.post('/cluster/install-nodes', {
            nodes: selectedNodes
        });
        
        // Update progress display
        results.forEach(result => {
            const item = document.getElementById(`progress-${result.node_id}`);
            if (item) {
                const badge = item.querySelector('.badge');
                badge.className = `badge ${result.status === 'completed' ? 'badge-success' : 'badge-error'}`;
                badge.textContent = result.status;
            }
        });
        
        DINS.Toast.success('Installation completed');
    } catch (error) {
        DINS.Toast.error(error.message);
    } finally {
        DINS.Loading.button(btn, false);
    }
}

async function initSwarm() {
    const confirmed = await DINS.Dialog.confirm(
        'Initialize Docker Swarm on this node? This node will become the swarm manager.',
        'Initialize Swarm'
    );
    
    if (!confirmed) return;
    
    const btn = document.getElementById('init-swarm-btn');
    DINS.Loading.button(btn, true);
    
    try {
        const result = await DINS.API.post('/cluster/init-swarm');
        
        if (result.status === 'initialized' || result.status === 'already_initialized') {
            DINS.Toast.success('Docker Swarm initialized');
            await refreshSwarmStatus();
        }
    } catch (error) {
        DINS.Toast.error(error.message);
    } finally {
        DINS.Loading.button(btn, false);
    }
}

async function refreshSwarmStatus() {
    try {
        const status = await DINS.API.get('/cluster/status');
        
        const statusBadge = document.getElementById('swarm-status');
        if (status.enabled) {
            statusBadge.className = 'badge badge-success';
            statusBadge.textContent = status.is_manager ? 'Manager' : 'Worker';
            document.getElementById('init-swarm-btn').disabled = true;
            document.getElementById('init-swarm-btn').textContent = 'Swarm Active';
        } else {
            statusBadge.className = 'badge badge-warning';
            statusBadge.textContent = 'Not Initialized';
        }
        
        // Update cluster nodes table
        renderClusterTable(status.nodes);
    } catch (error) {
        console.error('Failed to get swarm status:', error);
    }
}

function renderClusterTable(nodes) {
    const tbody = document.getElementById('cluster-tbody');
    
    if (!nodes || nodes.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="text-center">Swarm not initialized or no nodes</td></tr>';
        return;
    }
    
    tbody.innerHTML = nodes.map(node => `
        <tr>
            <td>${DINS.Utils.escapeHtml(node.ID || node.node_id || 'N/A')}</td>
            <td>${DINS.Utils.escapeHtml(node.Hostname || node.hostname || 'N/A')}</td>
            <td>${node.ManagerStatus ? 'Manager' : 'Worker'}</td>
            <td>${node.dins_role || 'worker'}</td>
            <td>
                <span class="badge ${node.Status === 'Ready' ? 'badge-success' : 'badge-warning'}">
                    ${node.Status || 'Unknown'}
                </span>
            </td>
        </tr>
    `).join('');
}

// Make init function available globally
window.init_cluster_swarm = init_cluster_swarm;
