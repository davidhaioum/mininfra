#!/bin/bash

# Configuration
CP_NODE="talos-cp-01"
WORKER_NODES=("talos-worker-01" "talos-worker-02")
MEMORY_WORKER=4

# Arguments
ACTION=$1
CONFIG_FILE=$2

# Function to check if config file is provided and exists
validate_config() {
    if [ -z "$CONFIG_FILE" ]; then
        echo "❌ Error: No configuration file provided."
        echo "Usage: $0 create <config-file.yaml>"
        exit 1
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Error: File '$CONFIG_FILE' not found."
        exit 1
    fi
}

case "$ACTION" in
    create)
        validate_config
        echo "🚀 Creating Talos cluster using: $CONFIG_FILE"

        # Start Control Plane
        limactl start --name="$CP_NODE" "$CONFIG_FILE"

        # Start Workers
        for node in "${WORKER_NODES[@]}"; do
            echo "🔧 Starting $node..."
            limactl start --name="$node" "$CONFIG_FILE" --memory $MEMORY_WORKER
        done
        ;;

    stop)
        echo "🛑 Stopping all nodes..."
        limactl stop "$CP_NODE"
        for node in "${WORKER_NODES[@]}"; do
            limactl stop "$node"
        done
        ;;

    delete)
        echo "🗑️ Deleting all nodes..."
        limactl delete -f "$CP_NODE"
        for node in "${WORKER_NODES[@]}"; do
            limactl delete -f "$node"
        done
        ;;

    *)
        echo "Usage: $0 {create|stop|delete} [config-file.yaml]"
        exit 1
        ;;
esac