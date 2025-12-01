# Deploy Kong on a Kind cluster

Disclaimer: This setup is NOT production-ready! It is a minimal setup to run a local cluster.

## Installation steps

1. Deploy your kind cluster

```bash
kind create cluster --config kind-config.yaml
```

kind-config.yaml

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: kong-cluster
nodes:
  - role: control-plane
    image: kindest/node:v1.34.0
    extraPortMappings:
      # ── Gateway ─────────────────────────────
      # HTTP entry for your apps via Gateway API
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
      # HTTPS entry (when you enable TLS later)
      - containerPort: 30443
        hostPort: 30443
        protocol: TCP
  - role: worker
    image: kindest/node:v1.34.0
```

2. Deploy Kong

```bash
helm repo add kong https://charts.konghq.com
helm repo update

# Kong 2.51.0
helm upgrade --install kong kong/kong \
  --namespace kong \
  --create-namespace \
  --version 2.51.0 \
  -f values-kong.yaml
```

values-kong.yaml

```yaml
---
# Run Kong in DB-less mode (no database)
env:
  database: "off"
  router_flavor: "traditional"

# Proxy service exposed as NodePort for kind
proxy:
  enabled: true
  type: NodePort
  http:
    enabled: true
    servicePort: 80
    containerPort: 8000
    nodePort: 30080   # kind extraPortMapping -> host:30080
  tls:
    enabled: false
    servicePort: 443
    containerPort: 8443
    # nodePort: 30443 # enable later if you want TLS via NodePort

# Do not expose the Admin API externally
admin:
  enabled: false

# No UDP proxy needed for now
udpProxy:
  enabled: false

# Kong Ingress Controller (KIC) + Gateway API support
ingressController:
  enabled: true

  env:
    kong_admin_tls_skip_verify: true
  rbac:
    create: true
    enableClusterRoles: true
    gatewayAPI:
      enabled: true

# Single replica is enough for local kind
autoscaling:
  enabled: false
replicaCount: 1
```

3. Create your Gateway and GatewayClass

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kong
  namespace: platform-plane
spec:
  gatewayClassName: kong
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
```

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kong
  annotations:
    konghq.com/gatewayclass-unmanaged: "true"
spec:
  controllerName: konghq.com/kic-gateway-controller
```

4. Deploy a Testing app

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
        - name: echo
          image: ealen/echo-server:latest
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: echo
spec:
  type: ClusterIP
  selector:
    app: echo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: echo-route
spec:
  parentRefs:
    - name: kong
      namespace: platform-plane
  hostnames:
    - "test.local"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: echo
          port: 80
```

5. Verify it works

```bash
$ curl -H "Host: test.local" http://localhost:30080
{"host":{"hostname":"test.local","ip":"::ffff:....",...
```

## Troubleshooting

```bash
# Verify Kong is working and registered the gateway
kubectl -n kong describe deploy kong-kong | grep gateway -i
# Verify the HTTP Route is status Accepted & Programmed
kubectl describe httproute echo-route
# Investivate the gateway and gatewayclass
kubectl describe gatewayclass kong
kubectl describe gateway kong
```

Networking flow:

```
curl
↓
kind NodePort (30080)
↓
iptables/nftables → CNI
↓
Kong Gateway (proxy)
↓
Gateway API
↓
HTTPRoute
↓
backendRef
↓
echo service
↓
Pods
```

## Some key takeways about Kong

### The Helm Charts

In the (Helm chart repository](https://github.com/Kong/charts/tree/main/charts)

* Ingress chart
  * an umbrella chart that install kong 2 times, one for the controller, one for the gateway
  * Technically you could scale the gateway base on your traffic without impacting the controller
  * The underlying chart is `kong/kong`.
* Kong chart
  * This is the one we use in this tutorial and is where we configure kong
* Kong operator or gateway operator are for more advanced use cases to manage Kong in one or multiple cluster

### Gateway API

* Kong supports [gateway-api](https://github.com/kubernetes-sigs/gateway-api) natively
* We can expose the gateway on a node port in the `proxy` settings.

### OSS VS Enterprise

OSS has good foundation blocks:

* Best-in-class and production-ready ingress gateway to replace ingress nginx for example
* Rich plugin eco-system (even for AI)

But OSS is limited compared to Enterprise license, especially if you want to explore AI Gateway fully open-source.