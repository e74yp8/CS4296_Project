#!/bin/bash
LOG_FILE="benchmark_results.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "LAB START: $(date)"
echo "=========================================="

# --- HELPER: WARM-UP FUNCTION ---
warmup_target() {
    local TARGET_URL=$1
    if [ -z "$TARGET_URL" ] || [ "$TARGET_URL" == "http://" ]; then
        echo "ERROR: Target URL is empty. Skipping warm-up."
        return 1
    fi
    echo "--> Warming up $TARGET_URL (40 seconds)..."
    wrk -t1 -c100 -d40s "$TARGET_URL" > /dev/null
    sleep 2
}

# 1. INSTALL EVERYTHING FIRST
echo "--- 1. Installing Engines (Docker, Multipass, wrk) ---"
sudo apt update
sudo apt install -y docker.io wrk snapd
sudo snap install multipass

# 2. FIX MULTIPASS AUTHENTICATION
echo "--- 2. Resetting Multipass Auth ---"
sudo snap stop multipass
sudo rm -rf /var/snap/multipass/common/data/multipassd/authenticated-certs
sudo rm -f /var/snap/multipass/common/data/multipassd/multipassd-passphrases
sudo snap start multipass
sleep 10 

# 3. CHECK HARDWARE
echo "--- 3. Checking Hardware Capabilities ---"
VIRT_CHECK=$(grep -Eoc '(vmx|svm)' /proc/cpuinfo)
if [ "$VIRT_CHECK" -eq 0 ]; then
    echo "ERROR: Nested Virtualization NOT active."
    exit 1
fi

# 4. LAUNCH VMS (Fixed Cleanup Logic)
echo "--- 4. Launching Nested VMs ---"
# Force cleanup of any existing/partially deleted VMs
sudo multipass delete --all
sudo multipass purge

echo "Launching victim-vm..."
sudo multipass launch --name victim-vm --cpus 1 --memory 1G
echo "Launching attacker-vm..."
sudo multipass launch --name attacker-vm --cpus 1 --memory 1G

# 5. SETUP VICTIM
echo "--- 5. Setting up Victim VM (Nginx Fix) ---"
sudo multipass exec victim-vm -- sudo rm -f /usr/sbin/policy-rc.d
sudo multipass exec victim-vm -- sudo apt update
sudo multipass exec victim-vm -- sudo apt install --reinstall -y nginx
sudo multipass exec victim-vm -- sudo systemctl start nginx

# Extract IP and verify it exists
VICTIM_IP=$(sudo multipass info victim-vm --format csv | grep victim-vm | cut -d, -f3)

if [ -z "$VICTIM_IP" ]; then
    echo "ERROR: Could not retrieve Victim VM IP. Exiting."
    exit 1
fi
echo "Victim VM IP: $VICTIM_IP"

# 6. VM BASELINE TEST
echo -e "\n--- 6. VM BASELINE TEST ---"
warmup_target "http://$VICTIM_IP/"
wrk -t2 -c100 -d40s "http://$VICTIM_IP/"

# 7. VM STRESS TEST
echo -e "\n--- 7. VM STRESS TEST ---"
sudo multipass exec attacker-vm -- sudo apt update 
sudo multipass exec attacker-vm -- sudo apt install -y stress-ng
sudo multipass exec attacker-vm -- bash -c "nohup stress-ng --cpu 2 --vm 1 --timeout 60s > /dev/null 2>&1 &"
sleep 10 
wrk -t2 -c100 -d40s "http://$VICTIM_IP/"

# 8. CONTAINER BASELINE TEST
echo -e "\n--- 8. CONTAINER BASELINE TEST ---"
sudo docker rm -f victim-ctr attacker-ctr 2>/dev/null
sudo docker run -d --name victim-ctr -p 8080:80 nginx
sleep 5
warmup_target "http://localhost:8080/"
wrk -t2 -c100 -d40s "http://localhost:8080/"

# 9. CONTAINER STRESS TEST
echo -e "\n--- 9. CONTAINER STRESS TEST ---"
sudo docker run --name attacker-ctr -d ubuntu bash -c "apt update && apt install -y stress-ng && stress-ng --cpu 2 --io 2 --vm 1 --vm-bytes 512M --timeout 60s"
sleep 10 
wrk -t2 -c100 -d40s "http://localhost:8080/"

# Cleanup
echo -e "\n--- Cleanup ---"
sudo docker stop victim-ctr attacker-ctr && sudo docker rm victim-ctr attacker-ctr
echo "=========================================="
echo "LAB COMPLETE. Results saved to: $LOG_FILE"