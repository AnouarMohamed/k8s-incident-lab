# Kubernetes Incident Response Lab

Production-style Kubernetes troubleshooting lab for a degraded checkout path in a small
e-commerce stack. The repo contains the remediated manifests, evidence-driven
documentation, and operator commands needed to reproduce and verify the fix.

## Executive Summary

At 03:14, checkout degradation was reported in the `incident-lab` namespace. The stack
looked like a single application outage, but the failure was intentionally split across
five independent Kubernetes operational domains:

| Domain | Failure | Fix |
| --- | --- | --- |
| Storage | Postgres PVC referenced a non-existent `fast-ssd` StorageClass | Use the cluster default StorageClass and run Postgres with a PVC-safe `PGDATA` subdirectory |
| Resources | `payment` had an unrealistically low memory limit | Increase request/limit so the pod stays stable |
| NetworkPolicy | `payment` allowed traffic from `app=checkout-service`, but checkout pods are `app=checkout` | Correct the pod selector |
| RBAC | `flag-controller` could list/get ConfigMaps but could not watch them | Add `watch` and harden the controller loop |
| Ingress | Traefik route referenced middleware in the wrong namespace | Use the same-namespace middleware reference |

Final verification:

```text
[postgres] PASS
[payment] PASS
[network (checkout->payment)] PASS
[controller] PASS
[ingress] PASS

All checks passing. Incident resolved.
```

## What This Demonstrates

- Kubernetes incident response under realistic constraints: no namespace deletion, no grader edits, no guess-and-reapply workflow.
- Debugging across storage, scheduling, resources, networking, RBAC, controllers, and ingress.
- Security-aware remediation: non-root workloads, explicit resource requests/limits, least-privilege RBAC, and namespace-scoped routing.
- Operator-quality documentation: incident report, runbook, remediation matrix, architecture notes, and verification procedure.

## Repository Layout

```text
.
|-- manifests/                 # Final remediated Kubernetes resources
|-- docs/
|   |-- ARCHITECTURE.md         # System topology and traffic flow
|   |-- INCIDENT_REPORT.md      # Timeline, symptoms, root causes, resolution
|   |-- LOCAL_CLUSTER_NOTES.md  # Notes from the verified local cluster
|   |-- PORTFOLIO_BRIEF.md      # Reviewer-facing project summary
|   |-- REMEDIATION_MATRIX.md   # Fault-by-fault evidence and fix mapping
|   |-- RUNBOOK.md              # Reproducible operator workflow
|   `-- SECURITY_NOTES.md       # DevSecOps hardening notes
|-- verify.sh                   # Lab grader, intentionally unchanged
`-- Makefile                    # Convenience operator targets
```

## Architecture

```text
client
  |
  v
Traefik IngressRoute
  |
  v
frontend -> checkout -> payment
               |
               +--> redis
               |
               +--> postgres StatefulSet + PVC

flag-controller -> watches feature-flags ConfigMap -> patches flag-controller-status
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full component model.

## Quick Start

Create a kind cluster:

```bash
kind create cluster --name incident-lab --config - <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
EOF
```

Install Traefik:

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ports.web.nodePort=30080 \
  --set service.type=NodePort
```

Wait for Traefik CRDs and the Traefik pod:

```bash
kubectl get crd ingressroutes.traefik.io middlewares.traefik.io
kubectl -n traefik rollout status deploy/traefik --timeout=120s
```

Apply the lab:

```bash
kubectl apply -f manifests/
```

Verify:

```bash
./verify.sh
```

If the cluster was created without host port mapping for `30080`, keep this running in a
second terminal during verification:

```bash
kubectl -n traefik port-forward --address 127.0.0.1 service/traefik 30080:80
```

## Operator Commands

```bash
make apply
make status
make events
make verify
```

## Documentation

- [Portfolio brief](docs/PORTFOLIO_BRIEF.md)
- [Incident report](docs/INCIDENT_REPORT.md)
- [Remediation matrix](docs/REMEDIATION_MATRIX.md)
- [Runbook](docs/RUNBOOK.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Security notes](docs/SECURITY_NOTES.md)
- [Local cluster notes](docs/LOCAL_CLUSTER_NOTES.md)

## Notes

`verify.sh` is the grader and is intentionally left unchanged. The final solution lives in
the original manifests plus documentation and operator helpers.
