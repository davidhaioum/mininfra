#!/bin/bash

cp ./colima.yaml ~/.colima/mininfra/colima.yaml

colima start mininfra

colima ssh -p mininfra -- sudo cp ~/.cert/ZscalerRootCertificate-2048-SHA256.crt /usr/local/share/ca-certificates/zscaler.crt
colima ssh -p mininfra -- sudo update-ca-certificates
colima ssh -p mininfra -- sudo service docker restart

kind create cluster --config kind-config.yaml

cilium install --version 1.18.4 --helm-values kubernetes/kube-system/cilium-values.yaml

kubectl apply -f kubernetes/namespaces.yaml

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

helm upgrade --install apisix apisix/apisix \
  --namespace platform-plane \
  --values planes/platform-plane/charts/values-apisix.yaml

kubectl apply -f planes/platform-plane/
kubectl apply -f planes/apps-plane/