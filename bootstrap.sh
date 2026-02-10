#!/bin/bash

cp ./colima.yaml ~/.colima/mininfra/colima.yaml

colima start mininfra

colima ssh -p mininfra -- sudo cp ~/.cert/ZscalerRootCertificate-2048-SHA256.crt /usr/local/share/ca-certificates/zscaler.crt
colima ssh -p mininfra -- sudo update-ca-certificates
colima ssh -p mininfra -- sudo service docker restart

kind create cluster --config kind-config.yaml

kubectx kind-mininfra

cilium install --version 1.18.4 --helm-values kubernetes/kube-system/cilium-values.yaml

kubectl apply -f kubernetes/namespaces.yaml

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

# Platform Plane
helm upgrade --install apisix apisix/apisix \
  --namespace platform-plane \
  --values planes/platform-plane/charts/values-apisix.yaml

kubectl apply -f planes/platform-plane/

# Apps plane
kubectl apply -f planes/apps-plane/

# Delivery Plane

helm upgrade --install forgejo oci://code.forgejo.org/forgejo-helm/forgejo \
  --namespace delivery-plane \
  --version 16.0.2 \
  --values planes/delivery-plane/charts/values-forgejio.yaml

# Data plane

helm repo add cnpg https://cloudnative-pg.github.io/charts
helm upgrade --install cnpg \
  --namespace data-plane \
  --version 0.27.1 \
  cnpg/cloudnative-pg \
  --values planes/data-plane/charts/values-cnpg.yaml

#helm upgrade --install valkey-operator \
#  --namespace data-plane \
#  oci://ghcr.io/hyperspike/valkey-operator \
#  --version v0.0.61-chart