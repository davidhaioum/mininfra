# Mininfra Lab

A local, opinionated, single-cluster Kubernetes lab designed to simulate a small cloud-native platform with multiple "planes":

- **Security plane** – identity, secrets, authorization
- **Observability plane** – metrics and traces
- **Platform plane** – GitOps, workflows, developer portal, registry
- **Sandbox plane** – application workloads, messaging, autoscaling, database, gateway

Everything runs on **one k3d (K3s) cluster** on a Mac, using **Cilium** as CNI and **Gateway API** (via Kong) as the entry point.

> This is a *learning / homelab* setup – not production, but conceptually close to how real platforms are built.

---

## High-level Architecture

All components are deployed into a **single Kubernetes cluster** called `Mininfra`, split logically into four namespaces (planes):

- `security-plane`
  - Keycloak (SSO)
  - Vault (secrets)
  - OpenFGA (authorization)
  - (Optional) CloudNativePG for infra databases

- `observability-plane`
  - Prometheus (via `kube-prometheus-stack` or similar)
  - Tempo (traces)
  - Grafana (dashboards)
  - OpenTelemetry Collector (gateway) – to be added

- `platform-plane`
  - Argo CD (GitOps)
  - Argo Workflows (pipelines / batch)
  - Simple container registry (e.g. `registry:2`) – to be added
  - Backstage (developer portal) – to be added later when the basics are stable

- `sandbox-plane`
  - Kong (Gateway API implementation, external HTTP entry)
  - NATS (JetStream, application messaging)
  - Keda (event-driven autoscaling, e.g. based on NATS)
  - CloudNativePG (application Postgres cluster)
  - OpenTelemetry Collector (agent) – to be added
  - Application microservices (HTTP + NATS + Postgres)

Cilium is used as the CNI in the cluster, and we can later add NetworkPolicies to isolate planes.

---

## Requirements

You need the following tools installed on your Mac:

- [k3d](https://k3d.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)

Hardware assumptions:

- Mac with Apple Silicon (M1 Pro)
- 16 GB RAM
- Enough disk space (at least 30–40 GB free is comfortable)

---

## Repository Layout

Recommended structure:

```text
Mininfra-lab/
  bootstrap.sh
  kubernetes/
    namespaces.yaml
  planes/
    observability/
      values-prometheus.yaml
      values-tempo.yaml
      # values-otel-gateway.yaml (later)
    security/
      values-keycloak.yaml
      values-vault.yaml
      # values-openfga.yaml (later as raw manifests)
    platform/
      values-argocd.yaml
      values-argowf.yaml
      # values-registry.yaml
      # values-backstage.yaml
    sandbox/
      values-kong.yaml
      values-nats.yaml
      values-keda.yaml
      values-cnpg.yaml
      # values-otel-agent.yaml
