# Run kubemark performance tests on Azure

This repo shows how to run k8s performance tests with kubemark cluster on Azure. Kubemark is a performance testing tool which allows users to run experiments on simulated clusters. The primary use case is scalability testing, as simulated clusters can be much bigger than the real ones. The objective is to expose problems with the master components (API server, controller manager or scheduler) that appear only on bigger clusters (e.g. small memory leaks).

Kubemark could be enabled on GCE using kubernetes official [automation scripts](https://github.com/kubernetes/kubernetes/tree/master/test/kubemark). However, it's hard to build kubemark cluster on other cloud providers or local environment. Although the [kubemark doc](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-scalability/kubemark-guide.md) shows it is possible to start up kubemark in existed cluster and there's support in the codebase, there are still many bugs in the automation scripts when building outside of GCE. Here I would show you the detailed steps to run scalability tests on Azure kubemark cluster.

## Prerequisites

You need to have a active Azure subscription to do the following steps.

First, a resource group is needed.

```bash
az login
az group create -n ${KUBEMARK_CLUSTER_RESOURCE_GROUP} -l ${LOCATION}
az group create -n ${EXTERNAL_CLUSTER_RESOURCE_GROUP} -l ${LOCATION}
```

We use [AKS-engine](https://github.com/Azure/aks-engine) to build k8s cluster on Azure.

```bash
git clone https://github.com/Azure/aks-engine.git
cd aks-engine
./scripts/get-akse.sh
aks-engine version # check status of aks-engine binary
```

Basically we need two clusters: kubemark cluster with a single master and an external cluster to run the pods serving as hollow nodes in kubemark cluster. You could refer to the [tutorial](https://github.com/Azure/aks-engine/blob/master/docs/tutorials/README.md) of AKS-engine for the detailed setup steps.

```bash
aks-engine generate external-cluster.json
aks-engine generate kubemark-cluster.json
```

When finished, the `_output/` directory would be made.

```bash
az group deployment create -g ${KUBEMARK_CLUSTER_RESOURCE_GROUP} --template-file _output/${KUBEMARK_CLUSTER_DNS_PREFIX}/azuredeploy.json --parameters _output/${KUBEMARK_CLUSTER_DNS_PREFIX}/azuredeploy.parameters.json
az group deployment create -g ${EXTERNAL_CLUSTER_RESOURCE_GROUP} --template-file _output/${EXTERNAL_CLUSTER_DNS_PREFIX}/azuredeploy.json --parameters _output/${EXTERNAL_CLUSTER_DNS_PREFIX}/azuredeploy.parameters.json
```

## Set up kubemark and external clusters

Set the kubeconfig of the external cluster, for example if your cluster location is `eastus2`:

```bash
export KUBECONFIG=_output/${EXTERNAL_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.eastus2.json
```

Build the external cluster

```bash
kubectl create namespace kubemark
kubectl create configmap node-configmap -n kubemark --from-literal=content.type="test-cluster"
kubectl create secret generic kubeconfig --type=Opaque --namespace=kubemark --from-file=kubelet.kubeconfig=_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.eastus2.json --from-file=kubeproxy.kubeconfig=_output/${KUBEMARK_CLUSTER_DNS_PREFIX}/kubeconfig/kubeconfig.eastus2.json
```

We need to build and push kubemark image.

```bash
# pull the k8s code
cd $GOPATH/src/k8s.io/
git clone git@github.com:kubernetes/kubernetes.git

# build kubemark binary
./hack/build-go.sh cmd/kubemark/
cp $GOPATH/src/k8s.io/kubernetes/_output/bin/kubemark $GOPATH/src/k8s.io/kubernetes/cluster/images/kubemark/

# build image
cd $GOPATH/src/k8s.io/kubernetes/cluster/images/kubemark/
make build

# tag and push
docker tag staging-k8s.gcr.io/kubemark:latest {{kubemark_image_registry}}/kubemark:{{kubemark_image_tag}}
docker push {{kubemark_image_registry}}/kubemark:{{kubemark_image_tag}}
```

Fill the {{numreplicas}}, {{kubemark_image_registry}} and {{kubemark_image_tag}} in `hollow-node.yaml` and create it.

```bash
kubectl apply -f hollow-node.yaml
```

> Note: number of replicas need to be more than 100 or the perf-test tool will report an error.

Once these pods are running, there should be corresponding hollow nodes running on the kubemark cluster. If there is taint `node.kubernetes.io/network-unavailable:NoSchedule` on the hollow nodes, we need to disable the `--configure-cloud-routes` flag on kube-controller-manager

```bash
# ssh to kubemark master
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# after disable the --configure-cloud-routes flag
kubectl apply -f /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Delete all the pod / hollow nodes on external / kubemark cluster and do once again. Now the hollow nodes are schedulable. We need to taint the kubemark master to prevent pods running on it.

```bash
kubectl taint node ${KUBEMARK_MASTER_NAME} node-role.kubernetes.io/master=:NoSchedule
```

## Run the performance tests

We use [kubernetes/perf-tests/clusterloader2](https://github.com/kubernetes/perf-tests/clusterloader2) to run the performance tests on kubemark cluster. First of all we need to set up the test environment.

```bash
source test-env.sh
```

We need to copy certificate and key of ETCD to kubemark master. It will be used in the test.

```bash
scp _output/${KUBEMARK_CLUSTER_DNS_PREFIX}/etcdclient.crt _output/${KUBEMARK_CLUSTER_DNS_PREFIX}/etcdclient.key azureuser@${KUBEMARK_MASTER_IP}:~/
```

Since the clusterloader2 is designed for GCE, we need to change the code a bit to have it run on Azure. See [the PR](https://github.com/kubernetes/perf-tests/pull/1039#issuecomment-584021587) for the detailed change.

```bash
git clone https://github.com/nilo19/perf-tests.git
cd perf-tests/
git checkout add-curl-https-config
```

Run the test suites through:

```bash
cd clusterloader2/
./run-e2e.sh
    --kubeconfig=$KUBE_CONFIG \
    --kubemark-root-kubeconfig=$KUBE_CONFIG \
    --provider=$PROVIDER \
    --masterip=$MASTER_SSH_IP \
    --master-internal-ip=$MASTER_INTERNAL_IP \
    --mastername=k8s-master-13504130-0 \
    --testconfig=$TEST_CONFIG \
    --report-dir=$REPORT_DIR \
    --alsologtostderr 2>&1 | tee $LOG_FILE
```
