#!/bin/bash
LOG_FILE="benchmark_results.log"
# This line ensures everything is logged to the file and the screen
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "LAB START: $(date)"
echo "=========================================="

# 1. INSTALL EVERYTHING FIRST
echo "--- 1. Installing Engines (Docker, Multipass, wrk) ---"
sudo apt update
sudo apt install -y docker.io wrk snapd
sudo snap install multipass

# 2. FIX MULTIPASS AUTHENTICATION (The "Stuck" Fix)
echo "--- 2. Resetting Multipass Auth ---"
sudo snap stop multipass
sudo rm -rf /var/snap/multipass/common/data/multipassd/authenticated-certs
sudo rm -f /var/snap/multipass/common/data/multipassd/multipassd-passphrase
sudo snap start multipass
sleep 10 # Essential delay for daemon initialization

# 3. CHECK HARDWARE
echo "--- 3. Checking Hardware Capabilities ---"
VIRT_CHECK=$(grep -Eoc '(vmx|svm)' /proc/cpuinfo)
if [ "$VIRT_CHECK" -eq 0 ]; then
    echo "ERROR: Nested Virtualization NOT active."
    echo "You MUST stop the instance and run the AWS CLI enable command."
    exit 1
fi
echo "Nested Virtualization is active ($VIRT_CHECK cores)."

# 4. LAUNCH VMS
echo "--- 4. Launching Nested VMs ---"
# Clean up any old attempts first
sudo multipass delete --all && sudo multipass purge
sudo multipass launch --name victim-vm --cpus 1 --memory 1G
sudo multipass launch --name attacker-vm --cpus 1 --memory 1G

# 5. SETUP VICTIM (Nginx Reinstall Fix)
echo "--- 5. Setting up Victim VM (Nginx Fix) ---"
sudo multipass exec victim-vm -- sudo rm -f /usr/sbin/policy-rc.d
sudo multipass exec victim-vm -- sudo apt update
sudo multipass exec victim-vm -- sudo apt install --reinstall -y nginx
sudo multipass exec victim-vm -- sudo systemctl start nginx

VICTIM_IP=$(sudo multipass info victim-vm --format csv | grep victim-vm | cut -d, -f3)
echo "Victim VM IP: $VICTIM_IP"

# 6. BENCHMARKS
echo -e "\n--- 6. VM BASELINE TEST ---"
wrk -t2 -c100 -d20s http://$VICTIM_IP/

echo -e "\n--- 7. VM STRESS TEST ---"
sudo multipass exec attacker-vm -- sudo apt update && sudo multipass exec attacker-vm -- sudo apt install -y stress-ng
sudo multipass exec attacker-vm -- stress-ng --cpu 2 --vm 1 --timeout 40s &
sleep 5
wrk -t2 -c100 -d20s http://$VICTIM_IP/

echo -e "\n--- 8. CONTAINER BASELINE TEST ---"
sudo docker run -d --name victim-ctr -p 8080:80 nginx
sleep 3
wrk -t2 -c100 -d20s http://localhost:8080/

echo -e "\n--- 9. CONTAINER STRESS TEST ---"
sudo docker run --name attacker-ctr -d ubuntu bash -c \
"apt update && apt install -y stress-ng && stress-ng --cpu 2 --io 2 --vm 1 --vm-bytes 512M --timeout 60s"
sleep 10
wrk -t2 -c100 -d20s http://localhost:8080/

echo -e "\n--- Cleanup ---"
sudo docker stop victim-ctr attacker-ctr && sudo docker rm victim-ctr attacker-ctr
echo "=========================================="
echo "LAB COMPLETE. Results saved to: $LOG_FILE"