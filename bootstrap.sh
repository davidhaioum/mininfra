#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="mininfra"

log() {
  echo
  echo "===== $* ====="
}

check_prereqs() {
  for bin in k3d kubectl helm; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      echo "Error: '$bin' is not installed or not in PATH."
      exit 1
    fi
  done
}

create_cluster() {
  if k3d cluster list 2>/dev/null | grep -q "^$CLUSTER_NAME"; then
    log "k3d cluster '$CLUSTER_NAME' already exists, skipping creation"
    return
  fi

  log "Creating k3d cluster '$CLUSTER_NAME'"
  k3d cluster create "$CLUSTER_NAME" \
    --servers 1 \
    --agents 2 \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--flannel-backend=none@server:0" \
    --image rancher/k3s:v1.34.1-k3s1
    --api-port 6443 \
    --port "8089:80@loadbalancer" \
    --port "8445:443@loadbalancer"
}

create_namespaces() {
  log "Applying namespaces"
  kubectl apply -f kubernetes/namespaces.yaml
}

install_cilium() {
  log "Installing Cilium (CNI)"

  helm repo add cilium https://helm.cilium.io >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1

  helm upgrade --install cilium cilium/cilium \
    --namespace kube-system \
    --set hubble.relay.enabled=false \
    --set hubble.ui.enabled=false \
    --set k8sServiceHost="k3d-$CLUSTER_NAME-server-0" \
    --set k8sServicePort=6443
}

install_observability_plane() {
  log "Installing Observability plane"

  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1

  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace observability-plane \
    --create-namespace=false \
    -f planes/observability/values-prometheus.yaml

  helm upgrade --install tempo grafana/tempo \
    --namespace observability-plane \
    -f planes/observability/values-tempo.yaml
}

install_security_plane() {
  log "Installing Security plane"

  helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
  helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null 2>&1 || true
  helm repo add codecentric https://codecentric.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1

  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace security-plane \
    --create-namespace=false \
    --set installCRDs=true

  helm upgrade --install vault hashicorp/vault \
    --namespace security-plane \
    -f planes/security/values-vault.yaml

  helm upgrade --install keycloak codecentric/keycloak \
    --namespace security-plane \
    -f planes/security/values-keycloak.yaml
}

install_platform_plane() {
  log "Installing Platform plane"

  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1

  helm upgrade --install argocd argo/argo-cd \
    --namespace platform-plane \
    --create-namespace=false \
    -f planes/platform/values-argocd.yaml

  helm upgrade --install argo-workflows argo/argo-workflows \
    --namespace platform-plane \
    -f planes/platform/values-argowf.yaml
}

install_sandbox_plane() {
  log "Installing Sandbox plane"

  helm repo add nats https://nats-io.github.io/k8s/helm/charts/ >/dev/null 2>&1 || true
  helm repo add kedacore https://kedacore.github.io/charts >/dev/null 2>&1 || true
  helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null 2>&1 || true
  helm repo add kong https://charts.konghq.com >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1

  helm upgrade --install nats nats/nats \
    --namespace sandbox-plane \
    -f planes/sandbox/values-nats.yaml

  helm upgrade --install keda kedacore/keda \
    --namespace sandbox-plane \
    -f planes/sandbox/values-keda.yaml

  helm upgrade --install cnpg cnpg/cloudnative-pg \
    --namespace sandbox-plane \
    -f planes/sandbox/values-cnpg.yaml

  helm upgrade --install kong kong/kong \
    --namespace sandbox-plane \
    -f planes/sandbox/values-kong.yaml
}

main() {
  check_prereqs
  create_cluster
  create_namespaces
  install_cilium
  #install_observability_plane
  #install_security_plane
  #install_platform_plane
  #install_sandbox_plane

  log "Base installation finished. Check pods with: kubectl get pods -A"
}

main "$@"
