#!/bin/bash

read -r -p "Please Enter Instance ID: " ID
if [ -z "$ID" ]; then
    echo "Error: Instance ID cannot be empty!"
    exit 1
fi

# Stop Instance
aws ec2 stop-instances --instance-id "${ID}"
aws ec2 wait instance-stopped --instance-id "${ID}"

# Enable Nested Virtualization (via CloudShell)
aws ec2 modify-instance-cpu-options --instance-id "${ID}" --nested-virtualization enabled

# Restart
aws ec2 start-instances --instance-id "${ID}"
