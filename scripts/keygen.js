const https = require('https');
const crypto = require('crypto');

const FIREBASE_URL = 'https://appchatai-313e3-default-rtdb.firebaseio.com';

function generateKey() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let key = '';
    for (let i = 0; i < 4; i++) {
        for (let j = 0; j < 4; j++) {
            key += chars[Math.floor(Math.random() * chars.length)];
        }
        if (i < 3) key += '-';
    }
    return key;
}

function firebaseRequest(path, method, data) {
    return new Promise((resolve, reject) => {
        const url = new URL(path + '.json', FIREBASE_URL);
        const options = {
            hostname: url.hostname,
            path: url.pathname,
            method: method,
            headers: { 'Content-Type': 'application/json' }
        };

        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                try { resolve(JSON.parse(body)); }
                catch { resolve(body); }
            });
        });

        req.on('error', reject);
        if (data) req.write(JSON.stringify(data));
        req.end();
    });
}

async function createKey(duration, count = 1) {
    const results = [];
    for (let i = 0; i < count; i++) {
        const key = generateKey();
        const keyData = {
            duration: duration,
            status: 'active',
            deviceId: '',
            createdAt: Date.now()
        };

        try {
            await firebaseRequest(`/keys/${key}`, 'PUT', keyData);
            results.push({ key, duration, status: 'created' });
            console.log(`[+] Created: ${key} (${duration})`);
        } catch (err) {
            console.error(`[!] Failed: ${key}: ${err.message}`);
            results.push({ key, duration, status: 'failed' });
        }
    }
    return results;
}

async function listKeys() {
    const data = await firebaseRequest('/keys', 'GET');
    if (!data) return [];
    return Object.entries(data).map(([key, val]) => ({ key, ...val }));
}

async function deleteKey(key) {
    await firebaseRequest(`/keys/${key}`, 'DELETE');
    console.log(`[+] Deleted key: ${key}`);
}

async function showStats() {
    const keys = await listKeys();
    const devices = await firebaseRequest('/devices', 'GET');

    console.log('\n=== GloryStore Key Stats ===');
    console.log(`Total keys: ${keys.length}`);
    console.log(`Active: ${keys.filter(k => k.status === 'active').length}`);
    console.log(`Used: ${keys.filter(k => k.status === 'used').length}`);

    const byDuration = {};
    keys.forEach(k => {
        byDuration[k.duration] = (byDuration[k.duration] || 0) + 1;
    });
    for (const [dur, count] of Object.entries(byDuration)) {
        console.log(`  ${dur}: ${count}`);
    }

    if (devices) {
        console.log(`\nActivated devices: ${Object.keys(devices).length}`);
    }
    console.log('');
}

const args = process.argv.slice(2);
const cmd = args[0];

if (cmd === 'create' && args[1]) {
    const duration = args[1];
    const count = parseInt(args[2]) || 1;
    if (!['1day', '7day', '30day'].includes(duration)) {
        console.error('Usage: node keygen.js create <1day|7day|30day> [count]');
        process.exit(1);
    }
    createKey(duration, count).then(() => process.exit(0));
} else if (cmd === 'stats') {
    showStats().then(() => process.exit(0));
} else if (cmd === 'list') {
    listKeys().then(keys => {
        console.log('\n=== All Keys ===');
        keys.forEach(k => {
            console.log(`${k.status === 'used' ? '[USED]' : '[ACTIVE]'} ${k.key} (${k.duration}) ${k.deviceId ? '-> ' + k.deviceId.substring(0, 16) + '...' : ''}`);
        });
        console.log('');
        process.exit(0);
    });
} else {
    console.log('Usage:');
    console.log('  node keygen.js create <1day|7day|30day> [count]  - Create keys');
    console.log('  node keygen.js stats                           - Show stats');
    console.log('  node keygen.js list                            - List all keys');
}
