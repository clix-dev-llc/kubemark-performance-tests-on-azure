#! /bin/bash

RESOURCE_GROUP=$1
MASTER_NAME=$2
PORT=$3

SUFFIX=$(echo "${MASTER_NAME}" | awk -F '-' '{print $3}')
LB_NAME="k8s-master-lb-$SUFFIX"
FIP_NAME="k8s-master-lbFrontEnd-$SUFFIX"
IP_CONFIG_NAME="ipconfig1"
DEFAULT_SSH_RULE_NAME="SSH-k8s-master-$SUFFIX-0"
NIC_NAME="k8s-master-$SUFFIX-nic-0"
NSG_NAME="k8s-master-$SUFFIX-nsg"

echo "creating load balancer inbound nat rule"
az network lb inbound-nat-rule create \
  -g "${RESOURCE_GROUP}" \
  --lb-name "${LB_NAME}" \
  -n forwarding22 \
  --protocol Tcp \
  --frontend-port "${PORT}" \
  --backend-port 22 \
  --frontend-ip-name "${FIP_NAME}"

echo "removing default ssh inbound nat rule"
az network nic ip-config inbound-nat-rule remove \
  -g "${RESOURCE_GROUP}" \
  --nic-name "${NIC_NAME}" \
  -n "${IP_CONFIG_NAME}" \
  --inbound-nat-rule "${DEFAULT_SSH_RULE_NAME}" \
  --lb-name "${LB_NAME}"

echo "adding ssh port forwarding nat rule to master's nic"
az network nic ip-config inbound-nat-rule add \
  --inbound-nat-rule forwarding22  \
  --ip-config-name "${IP_CONFIG_NAME}" \
  --nic-name "${NIC_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --lb-name "${LB_NAME}"

echo "adding network security rule to allow traffic into port ${PORT}"
az network nsg rule create \
  -g "${RESOURCE_GROUP}" \
  --nsg-name "${NSG_NAME}" \
  -n forwarding-nsg \
  --priority 234 \
  --destination-port-ranges "${PORT}" \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --description "Forward ssh traffic."
