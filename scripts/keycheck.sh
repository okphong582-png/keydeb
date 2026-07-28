#!/bin/bash

FIREBASE_URL="https://appchatai-313e3-default-rtdb.firebaseio.com"
CONFIG_DIR="$HOME/.config/glorystore"
ACTIVATION_FILE="$CONFIG_DIR/activation.dat"

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

check_activation() {
    if [ ! -f "$ACTIVATION_FILE" ]; then
        return 1
    fi
    local expires=$(awk '{print $3}' "$ACTIVATION_FILE")
    local now=$(date +%s)
    if [ "$now" -gt "$expires" ]; then
        rm -f "$ACTIVATION_FILE"
        return 1
    fi
    return 0
}

validate_key() {
    local key="$1"
    local encoded_key=$(echo "$key" | sed 's/[\/.]/_/g')
    local response=$(curl -s --max-time 15 \
        "$FIREBASE_URL/keys/$encoded_key.json" 2>/dev/null)
    
    if [ -z "$response" ] || [ "$response" = "null" ]; then
        return 1
    fi
    
    local status=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null)
    local duration=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('duration','1day'))" 2>/dev/null)
    
    if [ "$status" = "used" ]; then
        return 2
    fi
    
    local device_id=$(cat /etc/machine-id 2>/dev/null || hostname)
    local device_hash=$(echo "$device_id" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$device_id")
    
    curl -s -X DELETE --max-time 10 "$FIREBASE_URL/keys/$encoded_key.json" > /dev/null 2>&1
    
    local casexp=0
    case "$duration" in
        1day)  casexp=86400 ;;
        7day)  casexp=604800 ;;
        30day) casexp=2592000 ;;
        *)     casexp=86400 ;;
    esac
    local expires=$(( $(date +%s) + casexp ))
    
    curl -s -X PUT --max-time 10 \
        "$FIREBASE_URL/devices/$device_hash.json" \
        -d "{\"key\":\"$key\",\"activatedAt\":$(date +%s),\"expiresAt\":$expires}" > /dev/null 2>&1
    
    echo "$device_hash $key $expires" > "$ACTIVATION_FILE"
    chmod 600 "$ACTIVATION_FILE"
    return 0
}

show_dialog() {
    local msg="$1"
    local key=""
    
    if command -v zenity &>/dev/null; then
        key=$(zenity --entry \
            --title="GloryStore Activation" \
            --text="$msg" \
            --width=400 \
            --height=150)
    elif command -v kdialog &>/dev/null; then
        key=$(kdialog --inputtitle "GloryStore Activation" --inputbox "$msg")
    else
        echo "$msg"
        read -p "Enter Key: " key
    fi
    echo "$key"
}

show_success() {
    local msg="$1"
    if command -v zenity &>/dev/null; then
        zenity --info --title="GloryStore" --text="$msg" --width=350
    else
        echo "$msg"
    fi
}

show_error() {
    local msg="$1"
    if command -v zenity &>/dev/null; then
        zenity --error --title="GloryStore" --text="$msg" --width=350
    else
        echo "ERROR: $msg" >&2
    fi
}

if check_activation; then
    exit 0
fi

attempts=0
max_attempts=3

while [ $attempts -lt $max_attempts ]; do
    key=$(show_dialog "Nhập Key GloryStore để kích hoạt:\n(1 ngày / 7 ngày / 30 ngày)")
    
    if [ -z "$key" ]; then
        show_error "Vui lòng nhập key kích hoạt!"
        attempts=$((attempts + 1))
        continue
    fi
    
    validate_key "$key"
    result=$?
    
    if [ $result -eq 0 ]; then
        show_success "Kích hoạt thành công!\nCảm ơn bạn đã sử dụng GloryStore."
        exit 0
    elif [ $result -eq 2 ]; then
        show_error "Key đã được sử dụng trên thiết bị khác!"
    else
        show_error "Key không hợp lệ!\nVui lòng kiểm tra lại key."
    fi
    
    attempts=$((attempts + 1))
done

show_error "Kích hoạt thất bại sau $max_attempts lần thử."
exit 1
