# GloryStore KeyCheck System

Key validation system with Firebase Realtime Database integration.
Anti-crack protection, automatic DEB building via GitHub Actions.

## Features
- Key activation with 1-day, 7-day, 30-day duration
- Firebase Realtime Database key validation
- One-time key usage (auto-delete after activation)
- Anti-debug / anti-crack protection
- Device-locked activation
- Web UI for key management (GloryStore style)

## Build
```bash
./build.sh
```

## Web UI
Open `web/index.html` or deploy to Firebase Hosting.

Admin password: `GloryStore@2024Admin!`

## Generate Keys
```bash
node scripts/keygen.js create 1day 10
node scripts/keygen.js create 7day 5
node scripts/keygen.js create 30day 1
node scripts/keygen.js stats
```

## Firebase Config
- Database: appchatai-313e3-default-rtdb.firebaseio.com
- Rules: firebase.rules.json
