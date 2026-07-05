# Portfolio Brief

## Project

Kubernetes Incident Response Lab: checkout degradation across storage, resources,
NetworkPolicy, RBAC, and Traefik ingress.

## Positioning

This is a DevSecOps portfolio project, not a toy YAML dump. It shows the ability to
triage a multi-cause Kubernetes incident, harden the final manifests for admission
policies, and document the remediation in a way another operator can reproduce.

## Signals for Reviewers

| Signal | Evidence |
| --- | --- |
| Incident response | `docs/INCIDENT_REPORT.md` |
| Kubernetes troubleshooting | `docs/REMEDIATION_MATRIX.md` |
| Secure workload design | `docs/SECURITY_NOTES.md` |
| Production runbook quality | `docs/RUNBOOK.md` |
| Architecture clarity | `docs/ARCHITECTURE.md` |
| Reproducible verification | `verify.sh` and `Makefile` |

## Skills Demonstrated

- StatefulSet and PVC debugging
- StorageClass portability
- Container resource tuning
- NetworkPolicy diagnosis
- Service DNS and in-cluster traffic verification
- Namespace-scoped RBAC
- Controller reconciliation behavior
- Traefik IngressRoute and Middleware debugging
- Admission policy compatibility with non-root and resource limits
- Operational documentation and evidence capture

## Demo Script

```bash
make status
make network
make logs-controller
make ingress
make verify
```

If `localhost:30080` is not mapped by kind, start this first:

```bash
make forward-traefik
```

## Interview Narrative

The key point is that the incident was not one failure. Each symptom required validating a
different Kubernetes contract:

- PVC binding validated storage assumptions.
- Restart stability validated resource assumptions.
- `checkout -> payment` traffic validated NetworkPolicy and DNS.
- ConfigMap status updates validated RBAC and controller behavior.
- HTTP 200 through Traefik validated CRDs, route wiring, middleware scope, service
  endpoints, and external access.

The strongest engineering decision was to keep the repair scoped: patch the broken
resources in place, keep `verify.sh` untouched, and make the final manifests compatible
with common cluster admission controls.

## Final Proof

```text
[postgres] PASS
[payment] PASS
[network (checkout->payment)] PASS
[controller] PASS
[ingress] PASS

All checks passing. Incident resolved.
```
