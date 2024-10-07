#!/bin/bash
# This script will create an AKS cluster with dynamic IP allocation feature.
# 
# Usage: ./setup-podsubnet.sh
# 
# Copyright (c) 2024, Joey Chen.
# License: MIT

# Basic parameter
ranNum=$(echo $RANDOM)
rG=aks-${ranNum}
aks=aks-${ranNum}
vnet=aks-vnet
location=southeastasia

echo "Your resource group will be: ${rG}"
az group create -n ${rG} -l ${location} -o none

# Preparing VNet
az network vnet create -g ${rG} -n ${vnet} --address-prefixes 10.208.0.0/12 -o none 
az network vnet subnet create -n nodesubnet1 -g ${rG} --vnet-name ${vnet} --address-prefixes 10.208.0.0/24 -o none --no-wait
az network vnet subnet create -n nodesubnet2 -g ${rG} --vnet-name ${vnet} --address-prefixes 10.209.0.0/24 -o none --no-wait
az network vnet subnet create -n podsubnet1 -g ${rG} --vnet-name ${vnet} --address-prefixes 10.210.0.0/24 -o none --no-wait
az network vnet subnet create -n podsubnet2 -g ${rG} --vnet-name ${vnet} --address-prefixes 10.211.0.0/24 -o none

vnetId=$(az resource list -n ${vnet} -g ${rG} \
    --resource-type Microsoft.Network/virtualNetworks \
    --query [0].id -o tsv)

# Create AKS
az aks create -n ${aks} -g ${rG} \
    --no-ssh-key -o none \
    --nodepool-name agentpool \
    --node-os-upgrade-channel None \
    --node-count 1 \
    --node-vm-size Standard_A4_v2 \
    --nodepool-taints CriticalAddonsOnly=true:NoSchedule \
    --network-plugin azure \
    --vnet-subnet-id ${vnetId}/subnets/nodesubnet1 \
    --pod-subnet-id ${vnetId}/subnets/podsubnet1

az aks get-credentials -n ${aks} -g ${rG}

# Add new user nodepool with Podsubnet feature
az aks nodepool add --cluster-name ${aks} -g ${rG} -n userpool \
    --mode User \
    --node-count 1 \
    --node-vm-size Standard_A4_v2 \
    --vnet-subnet-id ${vnetId}/subnets/nodesubnet2 \
    --pod-subnet-id ${vnetId}/subnets/podsubnet2 \
    --no-wait -o none 
