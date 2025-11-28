async function init_devices_other() {
    console.log('Initializing section');
    const area = document.getElementById('content-area');
    if (area) {
        area.innerHTML = '<p>Section loaded. Configuration options coming soon.</p>';
    }
}
window.init_devices_other = init_devices_other;
