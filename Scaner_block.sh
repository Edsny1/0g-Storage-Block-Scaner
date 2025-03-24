#!/bin/bash

echo ""
echo "🏆OshVanK🏆 0g Storage Block Scanner| Cross Chain Service Provier"
echo "*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*.*"
echo ""

RPC_URL=$(grep 'blockchain_rpc_endpoint' ~/0g-storage-node/run/config.toml | cut -d '"' -f2)

while true; do 
    # Fetch local node status
    LOCAL_RESPONSE=$(curl -s -X POST http://127.0.0.1:5678 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
    logSyncHeight=$(echo "$LOCAL_RESPONSE" | jq '.result.logSyncHeight' 2>/dev/null)
    connectedPeers=$(echo "$LOCAL_RESPONSE" | jq '.result.connectedPeers' 2>/dev/null)

    # Fetch network block number
    NETWORK_RESPONSE=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')
    latestBlockHex=$(echo "$NETWORK_RESPONSE" | jq -r '.result' 2>/dev/null)

    # Validate and set fallback values
    if [[ "$logSyncHeight" =~ ^[0-9]+$ ]]; then
        local_status="$logSyncHeight"
    else
        local_status="N/A"
    fi

    [[ "$connectedPeers" =~ ^[0-9]+$ ]] || connectedPeers=0  # Default to 0 if error

    # Check for specific network RPC issues
    if [[ "$NETWORK_RESPONSE" == *"rate limit"* || "$NETWORK_RESPONSE" == *"Too Many Requests"* ]]; then
        network_status="N/A (RPC Rate Limited)"
    elif [[ -z "$NETWORK_RESPONSE" || "$NETWORK_RESPONSE" == "null" ]]; then
        network_status="N/A (RPC Timeout)"
    elif [[ "$latestBlockHex" =~ ^0x[0-9a-fA-F]+$ ]]; then
        latestBlock=$((16#${latestBlockHex:2}))
        network_status="$latestBlock"
    else
        network_status="N/A (Invalid RPC Response)"
    fi

    # Compute block difference only if both values are numbers
    if [[ "$logSyncHeight" =~ ^[0-9]+$ && "$latestBlock" =~ ^[0-9]+$ ]]; then
        block_diff=$((latestBlock - logSyncHeight))

        if [ "$block_diff" -le 5 ]; then
            diff_color="\\033[32m" # Green
        elif [ "$block_diff" -le 20 ]; then
            diff_color="\\033[33m" # Yellow
        else
            diff_color="\\033[31m" # Red
        fi

        block_status="(\033[0m${diff_color}Behind $block_diff\033[0m)"
    else
        block_status=""
    fi

    # Display results
    echo -e "Local Block: \033[32m$local_status\033[0m / Network Block: \033[33m$network_status\033[0m $block_status | Peers: \033[34m$connectedPeers\033[0m"

    sleep 5
done
