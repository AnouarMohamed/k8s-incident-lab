# Architecture

## Namespace

All application resources run in `incident-lab`.

## Services

| Component | Kind | Purpose |
| --- | --- | --- |
| `frontend` | Deployment + Service | Public application edge behind Traefik |
| `checkout` | Deployment + Service | Internal checkout service and network probe source |
| `payment` | Deployment + Service | Internal payment dependency |
| `redis` | Deployment + Service | Cache dependency |
| `postgres` | StatefulSet + headless Service + PVC | Durable database dependency |
| `flag-controller` | Deployment + ServiceAccount + Role | Reconciles feature flag changes into a status ConfigMap |
| `frontend` IngressRoute | Traefik CRD | Routes external HTTP traffic to `frontend` |

## Traffic Flow

```text
external client
  |
  v
Traefik web entrypoint
  |
  v
IngressRoute incident-lab/frontend
  |
  v
Service frontend:8080
  |
  v
Pod app=frontend

Pod app=frontend -> Service checkout:8080 -> Pod app=checkout
Pod app=checkout -> Service payment:8080 -> Pod app=payment
```

## Control Flow

```text
ConfigMap feature-flags
  |
  v
flag-controller
  |
  v
ConfigMap flag-controller-status
```

The controller uses its service account token and Kubernetes API access to observe
`feature-flags` and patch `flag-controller-status`.

## Network Policy Model

The namespace uses default-deny ingress and explicit allow rules:

| Target | Allowed source |
| --- | --- |
| `frontend` | Any source |
| `checkout` | `app=frontend` |
| `payment` | `app=checkout` |

The grader validates the critical dependency with:

```bash
kubectl -n incident-lab exec deploy/checkout -- \
  wget -q -O- --timeout=5 http://payment:8080/
```

## Storage Model

Postgres runs as a StatefulSet and uses a `volumeClaimTemplate`. The PVC intentionally
uses the cluster default StorageClass rather than a hard-coded class name. This makes the
manifest portable across kind, local-path, and standard managed-cluster defaults.

`PGDATA` is set to `/var/lib/postgresql/data/pgdata` so Postgres initializes a writable
subdirectory inside the mounted PVC. This avoids permission failures when the volume mount
root itself cannot be chmod'ed by a non-root container.
