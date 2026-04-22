#!/bin/bash

DOCKER="nginx_image"
KVM="guest_nginx_vm"
DATA_SOURCE_DIR="./local_data"
RESULT_DIR="./results"

echo "Extracting Packages..."
jq -r '.Results[].Packages[]? | "\(.Name)@\(.Version)"' "${DATA_SOURCE_DIR}/${DOCKER}.json" | sort -u >docker_pkgs.list
jq -r '.Results[].Packages[]? | "\(.Name)@\(.Version)"' "${DATA_SOURCE_DIR}/${KVM}.json" | sort -u >kvm_pkgs.list

DOCKER_COUNT=$(wc -l <docker_pkgs.list)
KVM_COUNT=$(wc -l <kvm_pkgs.list)

echo "Docker Packages No.: $DOCKER_COUNT"
echo "KVM Packages No.: $KVM_COUNT"

comm -13 kvm_pkgs.list docker_pkgs.list >"${RESULT_DIR}/docker_exclusive_packages.txt"
DOCKER_EXCLUSIVE_COUNT=$(wc -l <"${RESULT_DIR}/docker_exclusive_packages.txt")
echo "Docker Exclusive Packages No.: $DOCKER_EXCLUSIVE_COUNT"

comm -13 docker_pkgs.list kvm_pkgs.list >"${RESULT_DIR}/kvm_exclusive_packages.txt"
KVM_EXCLUSIVE_COUNT=$(wc -l <"${RESULT_DIR}/kvm_exclusive_packages.txt")
echo "KVM Exclusive Packages No.: $KVM_EXCLUSIVE_COUNT"
