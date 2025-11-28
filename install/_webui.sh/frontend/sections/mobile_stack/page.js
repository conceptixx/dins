async function init_mobile_stack() {
    console.log('Initializing section');
    const area = document.getElementById('content-area');
    if (area) {
        area.innerHTML = '<p>Section loaded. Configuration options coming soon.</p>';
    }
}
window.init_mobile_stack = init_mobile_stack;
