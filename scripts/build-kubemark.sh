#! /bin/bash

set -e
set -u
set -x

# pull the k8s code
cd $GOPATH/src/k8s.io/
if [ ! -d "kubernetes" ]; then
    git clone https://github.com/kubernetes/kubernetes
fi
cd kubernetes/

# build kubemark binary
./hack/build-go.sh cmd/kubemark/
cp _output/bin/kubemark cluster/images/kubemark/

# build image
cd cluster/images/kubemark/
make build
