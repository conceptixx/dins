/**
 * Node Selection Section JavaScript
 */

let nodesData = [];

async function init_nodes_selection() {
    console.log('Initializing Node Selection section');
    await loadNodes();
}

async function loadNodes() {
    try {
        nodesData = await DINS.API.get('/nodes/');
        renderNodesTable();
    } catch (error) {
        console.error('Failed to load nodes:', error);
        DINS.Toast.error('Failed to load nodes');
    }
}

function renderNodesTable() {
    const tbody = document.getElementById('nodes-tbody');
    
    if (!nodesData || nodesData.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="6" style="text-align: center; padding: 2rem; color: var(--text-muted);">
                    No nodes discovered. Run network discovery first.
                </td>
            </tr>
        `;
        return;
    }
    
    tbody.innerHTML = nodesData.map(node => `
        <tr>
            <td>
                <input type="checkbox" class="node-checkbox" data-node-id="${node.node_id}" 
                       ${node.selected ? 'checked' : ''}>
            </td>
            <td>${DINS.Utils.escapeHtml(node.node_id || 'N/A')}</td>
            <td>${DINS.Utils.escapeHtml(node.hostname || 'Unknown')}</td>
            <td>${DINS.Utils.escapeHtml(node.ip || 'N/A')}</td>
            <td>
                <span class="badge ${node.reachable_via_ssh ? 'badge-success' : 'badge-warning'}">
                    ${node.reachable_via_ssh ? 'Reachable' : 'Unknown'}
                </span>
            </td>
            <td>
                <select class="form-select" data-node-id="${node.node_id}" style="width: auto;">
                    <option value="worker" ${node.role === 'worker' ? 'selected' : ''}>Worker</option>
                    <option value="lead" ${node.role === 'lead' ? 'selected' : ''}>Lead</option>
                </select>
            </td>
        </tr>
    `).join('');
}

function toggleAllNodes(checked) {
    document.querySelectorAll('.node-checkbox').forEach(cb => {
        cb.checked = checked;
    });
}

async function saveNodeSelection() {
    const updates = [];
    
    document.querySelectorAll('.node-checkbox').forEach(cb => {
        const nodeId = cb.dataset.nodeId;
        const roleSelect = document.querySelector(`select[data-node-id="${nodeId}"]`);
        updates.push({
            node_id: nodeId,
            selected: cb.checked,
            role: roleSelect ? roleSelect.value : 'worker'
        });
    });
    
    try {
        await DINS.API.put('/nodes/', { nodes: updates });
        DINS.Toast.success('Node selection saved');
        await loadNodes();
    } catch (error) {
        DINS.Toast.error(error.message);
    }
}

window.init_nodes_selection = init_nodes_selection;
