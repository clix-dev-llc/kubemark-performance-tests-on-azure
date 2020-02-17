#! /bin/bash

set -ex

sudo bash -c 'cat >> /etc/kubernetes/addons/kube-proxy-daemonset.yaml << EOF
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: failure-domain.beta.kubernetes.io/zone
                operator: Exists
EOF'
