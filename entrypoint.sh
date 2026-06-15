#!/bin/bash
set -e

# Environment variables
API_PORT=${API_PORT:-44404}
MAC_ADDRESS=${MAC_ADDRESS:-}
NODE_LONG_NAME=${NODE_LONG_NAME:-VirtualNode}
NODE_SHORT_NAME=${NODE_SHORT_NAME:-VIRT}
CHANNEL_NAME=${CHANNEL_NAME:-LongFast}
CHANNEL_KEY=${CHANNEL_KEY:-AQ==}
LATITUDE=${LATITUDE:-}
LONGITUDE=${LONGITUDE:-}
POSITION_PRECISION=${POSITION_PRECISION:-}

# Create config directory if it doesn't exist
mkdir -p /var/opt/meshtasticd

# Generate MAC address if empty
if [ -z "$MAC_ADDRESS" ]; then
    MAC_ADDRESS=$(python3 -c "import random; print(':'.join(['%02X' % random.randint(0, 255) for _ in range(6)]))")
    echo "Generated random MAC address: $MAC_ADDRESS"
fi
export MAC_ADDRESS

# Ensure a basic config.yaml exists with the MAC address
if [ ! -f /var/opt/meshtasticd/config.yaml ]; then
    echo "Creating default pure-virtual config.yaml with MAC $MAC_ADDRESS"
    echo "Logging:" > /var/opt/meshtasticd/config.yaml
    echo "  Level: debug" >> /var/opt/meshtasticd/config.yaml
    echo "General:" >> /var/opt/meshtasticd/config.yaml
    echo "  MACAddress: $MAC_ADDRESS" >> /var/opt/meshtasticd/config.yaml
fi

# Check if database exists, if not, perform first-time setup
# Meshtasticd uses db.pb or db.yaml, or portduino_config.proto
# We can check for a proto file
if ls /var/opt/meshtasticd/*.proto 1> /dev/null 2>&1; then
    DB_EXISTS=true
else
    DB_EXISTS=false
fi

if [ "$DB_EXISTS" = false ]; then
    echo "First boot detected. Provisioning..."
    
    echo "Starting meshtasticd temporarily on port $API_PORT..."
    meshtasticd -c /var/opt/meshtasticd/config.yaml -d /var/opt/meshtasticd --port $API_PORT &
    DAEMON_PID=$!
    
    echo "Waiting for daemon to initialize and generate keys..."
    READY=false
    for i in {1..15}; do
        if meshtastic --host 127.0.0.1:$API_PORT --info >/dev/null 2>&1; then
            READY=true
            break
        fi
        sleep 2
    done
    
    if [ "$READY" = false ]; then
        echo "Failed to connect to meshtasticd. Provisioning aborted."
        kill -15 $DAEMON_PID
        exit 1
    fi
    
    echo "Configuring node parameters..."
    # Configure using Python API
    echo "Running provisioning script..."
    python3 /provision.py
    
    # Kill the temporary daemon
    echo "Shutting down temporary meshtasticd..."
    kill -15 $DAEMON_PID 2>/dev/null || true
    wait $DAEMON_PID 2>/dev/null || true
    echo "Provisioning complete."
fi

# Start normal execution
echo "Starting meshtasticd on port $API_PORT with MAC $MAC_ADDRESS..."
exec meshtasticd -c /var/opt/meshtasticd/config.yaml -d /var/opt/meshtasticd --port $API_PORT
