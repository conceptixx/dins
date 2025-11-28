async function init_stt_input() {
    console.log('Initializing section');
    const area = document.getElementById('content-area');
    if (area) {
        area.innerHTML = '<p>Section loaded. Configuration options coming soon.</p>';
    }
}
window.init_stt_input = init_stt_input;
