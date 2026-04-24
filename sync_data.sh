#!/bin/bash
# sync_results.sh

set -e
IP=""
KEY_PATH=""

mkdir -p local_data
echo "[LOG] Syncing results..."
scp -i "$KEY_PATH" ubuntu@$IP:~/results/*.json ./local_data/


echo "[SUCCESS] All data synced to local_data folder."