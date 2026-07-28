const firebaseConfig = {
    apiKey: "AIzaSyAmP7OU9mhsQruZ2BWXLzhK3HlWkKH-ftI",
    authDomain: "appchatai-313e3.firebaseapp.com",
    databaseURL: "https://appchatai-313e3-default-rtdb.firebaseio.com",
    projectId: "appchatai-313e3",
    storageBucket: "appchatai-313e3.firebasestorage.app",
    messagingSenderId: "618265386307",
    appId: "1:618265386307:web:81ab012e336977d90023f6",
    measurementId: "G-2952X10THM"
};

firebase.initializeApp(firebaseConfig);
const database = firebase.database();

const ADMIN_KEY = 'GloryStore@2024Admin!';

let currentFilter = 'all';
let selectedDuration = '1day';

function showToast(msg, type = 'info') {
    const t = document.getElementById('toast');
    t.textContent = msg;
    t.className = `toast ${type} show`;
    setTimeout(() => t.classList.remove('show'), 3000);
}

function login() {
    const pwd = document.getElementById('admin-password').value;
    if (pwd === ADMIN_KEY) {
        document.getElementById('login-screen').classList.remove('active');
        document.getElementById('dashboard-screen').classList.add('active');
        document.getElementById('login-error').textContent = '';
        loadDashboard();
        loadKeys();
        loadDevices();
        loadCharts();
        startClock();
    } else {
        document.getElementById('login-error').textContent = 'Invalid admin key!';
    }
}

document.getElementById('admin-password').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') login();
});

function logout() {
    document.getElementById('login-screen').classList.add('active');
    document.getElementById('dashboard-screen').classList.remove('active');
    document.getElementById('admin-password').value = '';
}

function showTab(tab) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    document.getElementById(`tab-${tab}`).classList.add('active');
    document.querySelector(`.nav-item[onclick="showTab('${tab}')"]`).classList.add('active');
}

function selectDuration(btn) {
    document.querySelectorAll('.dur-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    selectedDuration = btn.dataset.dur;
}

function adjustQty(delta) {
    const input = document.getElementById('key-quantity');
    let val = parseInt(input.value) || 1;
    val = Math.max(1, Math.min(100, val + delta));
    input.value = val;
}

function startClock() {
    function update() {
        const now = new Date();
        document.getElementById('clock-display').textContent =
            now.toLocaleDateString('vi-VN') + ' ' + now.toLocaleTimeString('vi-VN');
    }
    update();
    setInterval(update, 1000);
}

async function loadDashboard() {
    try {
        const snap = await database.ref('keys').once('value');
        const keys = snap.val() || {};
        const keyList = Object.entries(keys);

        const total = keyList.length;
        const active = keyList.filter(([_, v]) => v.status === 'active').length;
        const used = keyList.filter(([_, v]) => v.status === 'used').length;

        document.getElementById('total-keys').textContent = total;
        document.getElementById('active-keys').textContent = active;
        document.getElementById('used-keys').textContent = used;

        const devSnap = await database.ref('devices').once('value');
        const devs = devSnap.val() || {};
        document.getElementById('total-devices').textContent = Object.keys(devs).length;
    } catch (err) {
        console.error(err);
    }
}

async function loadCharts() {
    try {
        const snap = await database.ref('keys').once('value');
        const keys = snap.val() || {};
        const entries = Object.entries(keys);

        const counts = { '1day': 0, '7day': 0, '30day': 0 };
        entries.forEach(([_, v]) => {
            if (counts[v.duration] !== undefined) counts[v.duration]++;
        });

        const maxCount = Math.max(...Object.values(counts), 1);
        const chart = document.getElementById('duration-chart');
        chart.innerHTML = '';

        const labels = { '1day': '1 Day', '7day': '7 Days', '30day': '30 Days' };
        const colors = { '1day': '#ff6b35', '7day': '#3b82f6', '30day': '#10b981' };

        for (const [dur, count] of Object.entries(counts)) {
            const pct = (count / maxCount) * 100;
            const div = document.createElement('div');
            div.className = 'dur-bar';
            div.innerHTML = `
                <span class="dur-bar-label">${labels[dur]}</span>
                <div class="dur-bar-track">
                    <div class="dur-bar-fill" style="width:${pct}%;background:${colors[dur]}">${count > 0 ? count : ''}</div>
                </div>
                <span class="dur-bar-count">${count}</span>
            `;
            chart.appendChild(div);
        }
    } catch (err) {
        console.error(err);
    }
}

async function loadKeys(filter = 'all') {
    try {
        const snap = await database.ref('keys').once('value');
        const keys = snap.val() || {};
        const entries = Object.entries(keys);

        let filtered = entries;
        if (filter === 'active') filtered = entries.filter(([_, v]) => v.status === 'active');
        else if (filter === 'used') filtered = entries.filter(([_, v]) => v.status === 'used');

        const tbody = document.getElementById('keys-body');
        const empty = document.getElementById('keys-empty');

        if (filtered.length === 0) {
            tbody.innerHTML = '';
            empty.style.display = 'block';
            return;
        }
        empty.style.display = 'none';

        tbody.innerHTML = filtered.map(([key, val]) => `
            <tr>
                <td style="font-family:'Courier New',monospace;font-size:12px">${key}</td>
                <td>${val.duration || 'N/A'}</td>
                <td><span class="status-badge ${val.status || 'active'}">${val.status || 'active'}</span></td>
                <td style="font-family:'Courier New',monospace;font-size:11px;color:var(--text-secondary)">
                    ${val.deviceId ? val.deviceId.substring(0, 16) + '...' : '-'}
                </td>
                <td style="color:var(--text-secondary);font-size:11px">${val.createdAt ? new Date(val.createdAt).toLocaleString('vi-VN') : '-'}</td>
                <td>
                    <button class="btn-delete" onclick="deleteKey('${key}')"><i class="fas fa-trash"></i></button>
                </td>
            </tr>
        `).join('');
    } catch (err) {
        console.error(err);
    }
}

async function loadDevices() {
    try {
        const snap = await database.ref('devices').once('value');
        const devices = snap.val() || {};
        const entries = Object.entries(devices);

        const tbody = document.getElementById('devices-body');
        const empty = document.getElementById('devices-empty');

        if (entries.length === 0) {
            tbody.innerHTML = '';
            empty.style.display = 'block';
            return;
        }
        empty.style.display = 'none';

        const now = Math.floor(Date.now() / 1000);
        tbody.innerHTML = entries.map(([id, val]) => {
            const expired = val.expiresAt < now;
            const expiresStr = val.expiresAt ? new Date(val.expiresAt * 1000).toLocaleString('vi-VN') : '-';
            const activatedStr = val.activatedAt ? new Date(val.activatedAt * 1000).toLocaleString('vi-VN') : '-';
            return `
                <tr>
                    <td style="font-family:'Courier New',monospace;font-size:11px">${id.substring(0, 20)}...</td>
                    <td style="font-family:'Courier New',monospace;font-size:12px">${val.key || '-'}</td>
                    <td style="color:var(--text-secondary);font-size:11px">${activatedStr}</td>
                    <td style="color:var(--text-secondary);font-size:11px">${expiresStr}</td>
                    <td><span class="status-badge ${expired ? 'expired' : 'active'}">${expired ? 'Expired' : 'Active'}</span></td>
                </tr>
            `;
        }).join('');
    } catch (err) {
        console.error(err);
    }
}

function filterKeys(filter) {
    currentFilter = filter;
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    document.querySelector(`.filter-btn[data-filter="${filter}"]`).classList.add('active');
    loadKeys(filter);
}

async function generateKeys() {
    const qty = parseInt(document.getElementById('key-quantity').value) || 1;
    const btn = document.querySelector('.btn-generate');
    btn.disabled = true;
    btn.innerHTML = '<span class="loading-spinner"></span> Generating...';

    const result = [];
    const resultDiv = document.getElementById('gen-result');

    for (let i = 0; i < qty; i++) {
        const key = generateKeyString();
        const keyData = {
            duration: selectedDuration,
            status: 'active',
            deviceId: '',
            createdAt: Date.now()
        };

        try {
            await database.ref(`keys/${key}`).set(keyData);
            result.push(key);
        } catch (err) {
            console.error(err);
        }
    }

    resultDiv.className = 'gen-result success';
    resultDiv.innerHTML = `
        <p style="color:var(--accent-green);margin-bottom:12px">
            <i class="fas fa-check-circle"></i> Generated ${result.length}/${qty} keys (${selectedDuration})
        </p>
        ${result.map(k => `
            <div class="key-item">
                <span>${k}</span>
                <button class="copy-btn" onclick="copyKey('${k}', this)"><i class="fas fa-copy"></i> Copy</button>
            </div>
        `).join('')}
    `;

    btn.disabled = false;
    btn.innerHTML = '<i class="fas fa-bolt"></i> Generate Keys';
    showToast(`Generated ${result.length} keys successfully!`, 'success');
    loadDashboard();
    loadKeys(currentFilter);
    loadCharts();
}

function generateKeyString() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const segments = [];
    for (let i = 0; i < 4; i++) {
        let s = '';
        for (let j = 0; j < 4; j++) {
            s += chars[Math.floor(Math.random() * chars.length)];
        }
        segments.push(s);
    }
    return segments.join('-');
}

function copyKey(key, btn) {
    navigator.clipboard.writeText(key).then(() => {
        btn.innerHTML = '<i class="fas fa-check"></i> Copied!';
        setTimeout(() => { btn.innerHTML = '<i class="fas fa-copy"></i> Copy'; }, 2000);
    });
}

async function deleteKey(key) {
    if (!confirm(`Delete key: ${key}?`)) return;
    try {
        await database.ref(`keys/${key}`).remove();
        showToast('Key deleted successfully', 'success');
        loadKeys(currentFilter);
        loadDashboard();
        loadCharts();
    } catch (err) {
        showToast('Failed to delete key', 'error');
    }
}

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('admin-password').focus();
});
