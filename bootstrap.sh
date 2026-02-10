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

# System

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server \
  metrics-server/metrics-server \
  --version 3.13.0 \
  --namespace kube-system \
  --values kubernetes/kube-system/values-metrics-server.yaml

# Security Plane

helm repo add jetstack https://charts.jetstack.io --force-update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace security-plane \
  --version v1.19.2 \
  --set crds.enabled=true

# Platform Plane
helm upgrade --install apisix apisix/apisix \
  --namespace platform-plane \
  --values planes/platform-plane/charts/values-apisix.yaml

kubectl apply -f planes/platform-plane/

# Apps plane
kubectl apply -f planes/apps-plane/

# Delivery Plane

helm repo add argo https://argoproj.github.io/argo-helm

helm upgrade --install forgejo oci://code.forgejo.org/forgejo-helm/forgejo \
  --namespace delivery-plane \
  --version 16.0.2 \
  --values planes/delivery-plane/charts/values-forgejio.yaml

helm upgrade --install argocd \
  --namespace delivery-plane \
  --version 9.4.1 \
  argo/argo-cd \
  --values planes/delivery-plane/charts/values-argocd.yaml

helm upgrade --install argo-workflows \
  --namespace delivery-plane \
  --version 0.47.3 \
  argo/argo-workflows \
  --values planes/delivery-plane/charts/values-argo-workflows.yaml

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