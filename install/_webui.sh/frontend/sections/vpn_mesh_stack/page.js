async function init_vpn_mesh_stack() {
    console.log('Initializing section');
    const area = document.getElementById('content-area');
    if (area) {
        area.innerHTML = '<p>Section loaded. Configuration options coming soon.</p>';
    }
}
window.init_vpn_mesh_stack = init_vpn_mesh_stack;
