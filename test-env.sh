# kube config for kubernetes api
KUBE_CONFIG=config

# Provider setting
# Supported provider for xiaomi: local, kubemark, lvm-local, lvm-kubemark
PROVIDER='kubemark'

# SSH config for metrics' collection
export KUBE_SSH_KEY_PATH=${SSH_PUBLIC_KEY}
export KUBE_SSH_USER=azureuser
MASTER_SSH_IP=${KUBEMARK_MASTER_IP}

MASTER_INTERNAL_IP=${KUBEMARK_MASTER_INTERNAL_IP} # optional
MASTER_NAME=${KUBEMARK_MASTER_NAME} # optional

# etcd https params
export ETCD_CERTIFICATE=/home/azureuser/etcdclient.crt
export ETCD_KEY=/home/azureuser/etcdclient.key

# Clusterloader2 testing strategy config paths
# It supports setting up multiple test strategy. Each testing strategy is individual and serial.
TEST_CONFIG=testing/density/config.yaml
# TEST_CONFIG=testing/load/config.yaml

# Clusterloader2 testing override config paths
# It supports setting up multiple override config files. All of override config files will be applied to each testing strategy.
# OVERRIDE_CONFIG='testing/density/override/200-nodes.yaml'

# Log config
REPORT_DIR=./reports
LOG_FILE=log