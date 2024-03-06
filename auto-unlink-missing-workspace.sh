#!/bin/bash
# This script will auto-disable the AKS with non-exist workspace. 
# Make sure you have enough AAD permission before continue 
# Use "az account set --subscription <sub_id>" to set current subscription.
# 
# Usage: ./auto-unlink-missing-workspace.sh

if ! command -v az &> /dev/null
then
    echo "The command `az` could not be found"
    exit 1
fi

if ! command -v jq &> /dev/null
then
    echo "The command `jq` could not be found"
    exit 1
fi

bold="\033[1m"
normal="\033[0m"

AKS_res=$(az resource list --resource-type Microsoft.ContainerService/managedClusters --query [*].[name,resourceGroup] -o json --only-show-errors 2>/dev/null)

i=0
instance_num=$(jq -r "length"  <<< ${AKS_res})
pending_list="[]"
for((i=$i;i<$instance_num;++i)) do
    name=$(jq -r ".[${i}][0]" <<< ${AKS_res})
    rG=$(jq -r ".[${i}][1]" <<< ${AKS_res})

    echo "Checking the AKS \"${name}\"... Progress: $((i+1))/${instance_num}"
    output=$(az aks show --name $name --resource-group $rG --query addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID -o tsv --only-show-errors 2>/dev/null)
    if [[ ${output} ]]; then
        echo -e "Found linked workspace in AKS \"${bold}${name}${normal}\" under the resource group \"${bold}${rG}${normal}\". The workspace URI: ${bold}${output}${normal}"
        pending_list=$(jq ". + [[\"${name}\",\"${rG}\",\"${output}\"]]" <<< ${pending_list})
    fi

done 

i=0
pending_num=$(jq -r "length"  <<< ${pending_list})
malfunctioned_aks="[]"
for((i=$i;i<$pending_num;++i)) do
    name=$(jq -r ".[${i}][0]" <<< ${pending_list})
    rG=$(jq -r ".[${i}][1]" <<< ${pending_list})
    workspace=$(jq -r ".[${i}][2]" <<< ${pending_list})

    echo "Checking the workspace presence for AKS \"${name}\"... Progress: $((i+1))/${pending_num}"
    output=$(az resource show --ids $workspace --only-show-errors 2>/dev/null)
    if [[ -z ${output} ]]; then
        echo -e "Found workspace linked to AKS \"${bold}${name}${normal}\" is missing. AKS resource group: ${bold}${rG}${normal}; Workspace URI: ${bold}${workspace}${normal}"
        malfunctioned_aks=$(jq ". + [[\"${name}\",\"${rG}\"]]" <<< ${malfunctioned_aks})
    fi
done 

# malfunctioned_aks='[ [ "akari-test-ak1", "akari-aks" ], [ "joeylab-aks-gener1l", "joeylab" ] ]'

malfunctioned_num=$(jq -r "length"  <<< ${malfunctioned_aks})

if [[ ${malfunctioned_num} == 0 ]]; then
    echo "You don't have any AKS with missing workspace. Exiting..."
else
    echo "You have the following AKS linked with missing workspace:"
    i=0
    for((i=$i;i<$malfunctioned_num;++i)) do
        name=$(jq -r ".[${i}][0]" <<< ${malfunctioned_aks})
        rG=$(jq -r ".[${i}][1]" <<< ${malfunctioned_aks})

        echo "Name: ${bold}${name}${normal}; Resource Group: ${bold}${rG}${normal}"
    done 
    
    determinator=0
    until [[ ${determinator} == 1 ]]
    do
        pop_up="Do you want to proceed to auto remove link between workspace or you want to stop here? (Y: Continue; N: Stop)"
        read -p "${pop_up}" user_choice 
        if [[ "["yes", "Y", "y", "Yes"]" =~ ($DELIMITER|^)${user_choice}($DELIMITER|$) ]]; then
            i=0
            for((i=$i;i<$malfunctioned_num;++i)) do
                name=$(jq -r ".[${i}][0]" <<< ${malfunctioned_aks})
                rG=$(jq -r ".[${i}][1]" <<< ${malfunctioned_aks})

                echo "Proceeding on AKS \"${bold}${name}${normal}\" under resource group: \"${bold}${rG}${normal}\". Progress: $((i+1))/${malfunctioned_num}"
                az aks disable-addons -n ${name} -g ${rG} -a monitoring --only-show-errors --no-wait
            done 
            echo "The target AKS instance(s) are already under the process of unlinking workspace. Please check if your AKS back to work again in 5-15 minutes."
            determinator=1
            exit 0
        elif  [[ "["no", "N", "n", "No"]" =~ ($DELIMITER|^)${user_choice}($DELIMITER|$) ]]; then
            determinator=1
            exit 0
        else
            echo "Wrong input, please try again."
        fi
    done
fi
