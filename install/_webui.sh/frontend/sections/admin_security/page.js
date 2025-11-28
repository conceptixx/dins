/**
 * Admin & Security Section JavaScript
 */

let currentEmail = '';

async function init_admin_security() {
    console.log('Initializing Admin & Security section');
    
    // Load current status
    await loadAdminStatus();
    
    // Setup form handlers
    setupFormHandlers();
}

async function loadAdminStatus() {
    try {
        const status = await DINS.API.get('/admin/status');
        updateStatusDisplay(status);
        
        // Pre-fill username if set
        if (status.username) {
            document.getElementById('admin-username').value = status.username;
        }
        
        // Pre-fill email if set
        if (status.email) {
            document.getElementById('admin-email').value = status.email;
            currentEmail = status.email;
        }
        
    } catch (error) {
        console.error('Failed to load admin status:', error);
        DINS.Toast.error('Failed to load admin status');
    }
}

function updateStatusDisplay(status) {
    // Update main status badge
    const setupStatus = document.getElementById('setup-status');
    if (status.setup_complete) {
        setupStatus.className = 'badge badge-success';
        setupStatus.textContent = 'Complete';
    } else {
        setupStatus.className = 'badge badge-warning';
        setupStatus.textContent = 'Incomplete';
    }
    
    // Update individual status items
    updateStatusItem('status-username', status.username ? 'Set' : 'Not Set', !!status.username);
    updateStatusItem('status-email', status.email_verified ? 'Verified' : 'Not Verified', status.email_verified);
    updateStatusItem('status-password', status.password_set ? 'Set' : 'Not Set', status.password_set);
    updateStatusItem('status-2fa', status.two_factor_required ? 'Enabled' : 'Not Configured', status.two_factor_required);
}

function updateStatusItem(id, text, isGood) {
    const element = document.getElementById(id);
    element.textContent = text;
    element.className = `badge ${isGood ? 'badge-success' : 'badge-warning'}`;
}

function setupFormHandlers() {
    // Username form
    document.getElementById('username-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = document.getElementById('admin-username').value;
        
        try {
            await DINS.API.post('/admin/username', { username });
            DINS.Toast.success('Username saved');
            await loadAdminStatus();
        } catch (error) {
            DINS.Toast.error(error.message);
        }
    });
    
    // Email form (send verification)
    document.getElementById('email-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const email = document.getElementById('admin-email').value;
        
        const btn = document.getElementById('send-code-btn');
        DINS.Loading.button(btn, true);
        
        try {
            await DINS.API.post('/setup/send-verification-email', { email });
            currentEmail = email;
            DINS.Toast.success('Verification code sent to your email');
            document.getElementById('verify-form').style.display = 'block';
        } catch (error) {
            DINS.Toast.error(error.message);
        } finally {
            DINS.Loading.button(btn, false);
        }
    });
    
    // Verify email form
    document.getElementById('verify-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const code = document.getElementById('verification-code').value;
        
        try {
            await DINS.API.post('/setup/verify-email', { 
                email: currentEmail, 
                code: code 
            });
            DINS.Toast.success('Email verified successfully');
            document.getElementById('verify-form').style.display = 'none';
            await loadAdminStatus();
        } catch (error) {
            DINS.Toast.error(error.message);
        }
    });
    
    // Password form
    document.getElementById('password-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const password = document.getElementById('admin-password').value;
        const confirm = document.getElementById('admin-password-confirm').value;
        
        if (password !== confirm) {
            DINS.Toast.error('Passwords do not match');
            return;
        }
        
        if (password.length < 8) {
            DINS.Toast.error('Password must be at least 8 characters');
            return;
        }
        
        try {
            await DINS.API.post('/setup/admin-password', { password });
            DINS.Toast.success('Password set successfully');
            document.getElementById('admin-password').value = '';
            document.getElementById('admin-password-confirm').value = '';
            await loadAdminStatus();
        } catch (error) {
            DINS.Toast.error(error.message);
        }
    });
    
    // Password strength indicator
    document.getElementById('admin-password').addEventListener('input', (e) => {
        const strength = checkPasswordStrength(e.target.value);
        const indicator = document.getElementById('password-strength');
        indicator.textContent = `Password strength: ${strength.label}`;
        indicator.style.color = strength.color;
    });
    
    // 2FA form
    document.getElementById('twofa-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const emailEnabled = document.getElementById('twofa-email').checked;
        const totpEnabled = document.getElementById('twofa-totp').checked;
        
        try {
            await DINS.API.post('/admin/two-factor', {
                required: true,
                email_otp_enabled: emailEnabled,
                totp_enabled: totpEnabled
            });
            DINS.Toast.success('2FA settings saved');
            await loadAdminStatus();
        } catch (error) {
            DINS.Toast.error(error.message);
        }
    });
}

function checkPasswordStrength(password) {
    let score = 0;
    
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (/[a-z]/.test(password)) score++;
    if (/[A-Z]/.test(password)) score++;
    if (/[0-9]/.test(password)) score++;
    if (/[^a-zA-Z0-9]/.test(password)) score++;
    
    if (score <= 2) return { label: 'Weak', color: '#ef4444' };
    if (score <= 4) return { label: 'Medium', color: '#f59e0b' };
    return { label: 'Strong', color: '#22c55e' };
}

// Make init function available globally
window.init_admin_security = init_admin_security;
