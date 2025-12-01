# Deploy Cilium on a Kind cluster with Colima on Mac OS M1

Disclaimer: Not-production ready! This is a very minimal config.

```bash
brew install colima kind
```

1. Start colima

```bash
colima start

colima ssh -p mininfra -- sudo cp ~/.cert/ZscalerRootCertificate-2048-SHA256.crt /usr/local/share/ca-certificates/zscaler.crt
colima ssh -p mininfra -- sudo update-ca-certificates
colima ssh -p mininfra -- sudo service docker restart
```

2. Create your cluster

```bash
kind create cluster --config kind-config.yaml
```

kind-config.yaml

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cilium-kind
nodes:
  - role: control-plane
    image: kindest/node:v1.34.0
    extraPortMappings:
      # ── Cilium Hubble ──────────────────────────────────────────────
      # Hubble UI (we’ll use 12000 inside the cluster)
      - containerPort: 12000
        hostPort: 31200
        protocol: TCP
      # Hubble gRPC (relay) – often 4244
      - containerPort: 4244
        hostPort: 31244
        protocol: TCP
  - role: worker
    image: kindest/node:v1.34.0
#- role: worker
networking:
  disableDefaultCNI: true # needed for Cillium
```

```bash
cilium install --version 1.18.4 --helm-values cilium-values.yaml
```

cilium-values.yaml

```yaml
cluster:
  name: cilium-kind
kubeProxyReplacement: false # Can be partial after
ipam:
  # For kind cluster
  mode: kubernetes
gatewayAPI:
  enabled: true # Put false if you plan to use another gateway solution like Kong
hubble: # Cilium provided UI
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
operator:
  replicas: 1
```