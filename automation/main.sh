#! /bin/bash

set -e
set -u
set -x

WORKING_DIR=$(dirname "${BASH_SOURCE[0]}")
ROOT_DIR="${WORKING_DIR}"/..

source "${WORKING_DIR}"/common.sh

function ssh_and_do {
    if [ -f "$2" ]; then
        ssh -o StrictHostKeyChecking=no -i "${PRIVATE_KEY}" kubernetes@"$1" < "$2"
    else
        ssh -o StrictHostKeyChecking=no -i "${PRIVATE_KEY}" kubernetes@"$1" "$2"
    fi
}

function create_resource_group {
    az group create -n "$1" -l "${LOCATION}" --tags "autostop=no"
}

function cleanup_resource_group {
    echo "cleaning up resource groups..."

    az group delete -n "${KUBEMARK_CLUSTER_RESOURCE_GROUP}" -y &
    az group delete -n "${EXTERNAL_CLUSTER_RESOURCE_GROUP}" -y &
    wait
}

trap cleanup_resource_group ERR EXIT

function get_master_ip {
    KUBEMARK_MASTER_IP=$(az network public-ip list -g "$1" | jq '.[0].ipAddress' | sed 's/"//g')
}

function build_kubemark_cluster {
    aks-engine generate "$1"

    KUBEMARK_CLUSTER_DNS_PREFIX=$(jq '.properties.masterProfile.dnsPrefix' "$1" | sed 's/"//g')
    az group deployment create \
      -g "${KUBEMARK_CLUSTER_RESOURCE_GROUP}" \
      --template-file "${ROOT_DIR}/_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/azuredeploy.json" \
      --parameters "${ROOT_DIR}/_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/azuredeploy.parameters.json"

    get_master_ip "${KUBEMARK_CLUSTER_RESOURCE_GROUP}"
    ssh_and_do "${KUBEMARK_MASTER_IP}" "${WORKING_DIR}/build-kubemark-master.sh"

    scp -i "${PRIVATE_KEY}" "${ROOT_DIR}/_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/etcdclient.crt" \
      "${ROOT_DIR}/_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/etcdclient.key" kubernetes@"${KUBEMARK_MASTER_IP}":~/
}

function build_external_cluster {
    aks-engine generate "$1"

    EXTERNAL_CLUSTER_DNS_PREFIX=$(jq '.properties.masterProfile.dnsPrefix' "$1" | sed 's/"//g')
    az group deployment create \
      -g "${EXTERNAL_CLUSTER_RESOURCE_GROUP}" \
      --template-file "${ROOT_DIR}/_output/${EXTERNAL_CLUSTER_DNS_PREFIX}/azuredeploy.json" \
      --parameters "${ROOT_DIR}/_output/${EXTERNAL_CLUSTER_DNS_PREFIX}/azuredeploy.parameters.json"
    
    export KUBECONFIG="${ROOT_DIR}/_output/${EXTERNAL_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.${LOCATION}.json"
    kubectl create namespace "kubemark"
    kubectl create configmap node-configmap -n "kubemark" --from-literal=content.type="test-cluster"
    kubectl create secret generic kubeconfig \
      --type=Opaque \
      --namespace="kubemark" \
      --from-file="kubelet.kubeconfig=${ROOT_DIR}/_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.${LOCATION}.json" \
      --from-file="kubeproxy.kubeconfig=${ROOT_DIR}/_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.${LOCATION}.json"
}

create_resource_group "${KUBEMARK_CLUSTER_RESOURCE_GROUP}" &
create_resource_group "${EXTERNAL_CLUSTER_RESOURCE_GROUP}" &
wait

build_kubemark_cluster "${ROOT_DIR}/kubemark-cluster-2.json"
build_external_cluster "${ROOT_DIR}/external-cluster-1.json"

export KUBECONFIG="${ROOT_DIR}/_output/${EXTERNAL_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.${LOCATION}.json"

kubectl apply -f "${ROOT_DIR}/hollow-node-1.yaml"
sleep 30

export KUBECONFIG="${ROOT_DIR}/_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.${LOCATION}.json"

while : 
do
    none_count=$(kubectl get no | awk '{print $3}' | grep "<none>" | wc -l)
    node_count=$(kubectl get no | grep "hollow" | wc -l)
    if [ "${node_count}" -eq "${KUBEMARK_SIZE}" ] && [ "${none_count}" -eq 0  ]; then
        break
    else 
        sleep 10
    fi
done

export KUBE_CONFIG="${ROOT_DIR}/_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.${LOCATION}.json"

# Provider setting
# Supported provider for xiaomi: local, kubemark, lvm-local, lvm-kubemark
PROVIDER="kubemark"

# SSH config for metrics' collection
export KUBE_SSH_KEY_PATH="${PRIVATE_KEY}"
export KUBE_SSH_USER="kubernetes"
MASTER_SSH_IP="${KUBEMARK_MASTER_IP}"

MASTER_NAME="$(kubectl get no | grep "k8s-master" | awk '{print $1}')"

# etcd https params
export ETCD_CERTIFICATE=/home/kubernetes/etcdclient.crt
export ETCD_KEY=/home/kubernetes/etcdclient.key

# apiserver
export GET_APISERVER_PPROF_BY_K8S_CLIENT=true

# Clusterloader2 testing strategy config paths
# It supports setting up multiple test strategy. Each testing strategy is individual and serial.
TEST_CONFIG="${TEST_CONFIG:-${ROOT_DIR}/testing/density/config.yaml}"
# TEST_CONFIG="${ROOT_DIR}/testing/load/config.yaml"

# Clusterloader2 testing override config paths
# It supports setting up multiple override config files. All of override config files will be applied to each testing strategy.
# OVERRIDE_CONFIG='testing/density/override/200-nodes.yaml'

# Log config
REPORT_DIR="${ROOT_DIR}/reports"
LOG_FILE="${ROOT_DIR}/log"

CLUSTERLOADER2="${ROOT_DIR}/bin/clusterloader-$(uname -s)"

${CLUSTERLOADER2} \
    --kubeconfig="${KUBE_CONFIG}" \
    --kubemark-root-kubeconfig="${KUBE_CONFIG}" \
    --provider="${PROVIDER}" \
    --masterip="${MASTER_SSH_IP}" \
    --master-internal-ip="10.240.255.5" \
    --mastername="${MASTER_NAME}" \
    --testconfig="${TEST_CONFIG}" \
    --report-dir="${REPORT_DIR}" \
    --alsologtostderr 2>&1 | tee "${LOG_FILE}"
