#!/usr/bin/env bash
set -e
DEVICE_IP="${1:-192.168.1.143}"
ZIP_PATH="$(dirname "$0")/../builds/portmaster/supermarketthenight.zip"

if [ ! -f "$ZIP_PATH" ]; then
    echo "Error: $ZIP_PATH not found. Run ./scripts/build_portmaster.sh first."
    exit 1
fi

echo "Deploying to ark@$DEVICE_IP..."
ASKPASS_SCRIPT="$(mktemp)"
cat << 'PWE' > "$ASKPASS_SCRIPT"
#!/bin/sh
echo "ark"
PWE
chmod +x "$ASKPASS_SCRIPT"

trap 'rm -f "$ASKPASS_SCRIPT"' EXIT

export SSH_ASKPASS_REQUIRE=force
export SSH_ASKPASS="$ASKPASS_SCRIPT"
export DISPLAY=:0

echo "Sending zip to $DEVICE_IP:/tmp/..."
scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$ZIP_PATH" "ark@$DEVICE_IP:/tmp/supermarketthenight.zip"

echo "Extracting to /roms2/ports/ on $DEVICE_IP..."
ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "ark@$DEVICE_IP" "unzip -o /tmp/supermarketthenight.zip -d /roms2/ports/ && rm -f '/roms2/ports/supermarketthenight/supermarketthenight.gptk' /tmp/supermarketthenight.zip && chmod +x '/roms2/ports/Supermarket The Night.sh'"

echo "Deployment finished successfully!"
