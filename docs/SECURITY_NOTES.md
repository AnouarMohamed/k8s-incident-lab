# Security Notes

## Admission-Friendly Workloads

The remediated manifests are compatible with common baseline admission policies:

- `runAsNonRoot: true`
- explicit `runAsUser` and `runAsGroup`
- `allowPrivilegeEscalation: false`
- resource requests and limits on containers

This matters because many real clusters enforce Kyverno, Gatekeeper, PSA, or managed
admission profiles. A lab that only works on an unrestricted cluster is not a strong
production signal.

## RBAC

The `flag-controller` service account is namespace-scoped. It can manage ConfigMaps only
inside `incident-lab`:

```yaml
resources: ["configmaps"]
verbs: ["get", "list", "watch", "create", "patch", "update"]
```

No ClusterRole is required.

## Network Policy

The namespace uses default-deny ingress and explicit application allow rules. The critical
policy is:

```text
payment accepts ingress from app=checkout
```

This is narrow enough to express service intent while still allowing the verifier to prove
the real checkout-to-payment path.

## Storage

The Postgres manifest does not hard-code a StorageClass. This avoids coupling the app to a
provider-specific class name and lets the cluster default provisioner handle the PVC.

`PGDATA` points to a subdirectory under the PVC mount so non-root Postgres can initialize
data safely without requiring root ownership changes on the mount root.

## Ingress

Traefik middleware is referenced by local name:

```yaml
middlewares:
- name: frontend-headers
```

Cross-namespace middleware references are intentionally avoided. They require explicit
Traefik configuration and are harder to audit.

## Image Notes

Images are versioned tags rather than `latest`. This improves reproducibility and avoids
common image admission policy failures.
