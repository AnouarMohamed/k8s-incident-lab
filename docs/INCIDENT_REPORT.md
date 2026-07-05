# Incident Report

## Summary

Checkout degradation was caused by five independent Kubernetes misconfigurations. The
symptoms appeared application-related, but the actual failures spanned storage,
resources, network policy, RBAC, and ingress routing.

## Impact

- `frontend` ingress traffic could not reliably return HTTP 200.
- `checkout` could not call `payment`.
- `payment` was unstable under its configured memory limit.
- `flag-controller` could not reliably update controller status.
- `postgres` could not start because its PVC could not bind with the requested storage
  class.

## Detection

The lab grader checked:

```text
[postgres] pod Running, PVC Bound
[payment] pod Running, restart count stable
[network] checkout can reach payment:8080
[controller] flag-controller updates status ConfigMap
[ingress] Traefik localhost route returns HTTP 200
```

## Root Causes

| Root cause | Evidence | Resolution |
| --- | --- | --- |
| Invalid storage class | PVC requested `fast-ssd`, which was not available | Removed `storageClassName` to use the default class |
| Unsafe Postgres volume path | Non-root Postgres could not chmod the PVC mount root | Set `PGDATA=/var/lib/postgresql/data/pgdata` |
| Payment memory too low | Limit was `6Mi`, too small for stable runtime | Raised memory request/limit |
| NetworkPolicy selector mismatch | Policy allowed `app=checkout-service`; pod label was `app=checkout` | Corrected selector |
| Missing RBAC verb | Controller needed to observe ConfigMap changes | Added `watch` to ConfigMap verbs |
| Wrong middleware reference | IngressRoute referenced `frontend-headers@kube-system` | Referenced same-namespace `frontend-headers` |

## Resolution

The fixed manifests were applied in place. The namespace was not deleted, and `verify.sh`
was not modified.

Final result:

```text
All checks passing. Incident resolved.
```

## Lessons

- Similar symptoms do not imply a shared root cause.
- Storage, RBAC, and network policy failures often surface as application outages.
- Admission policy compatibility should be handled in manifests, not bypassed at runtime.
- Verification should include real traffic from the affected workload, not only service
  existence checks.
