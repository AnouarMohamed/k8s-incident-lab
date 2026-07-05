# Remediation Matrix

| Check | Broken state | Investigation command | Fix | Manifest |
| --- | --- | --- | --- | --- |
| Postgres | PVC stuck Pending due to unavailable `fast-ssd` StorageClass | `kubectl -n incident-lab describe pvc data-postgres-0` | Use default StorageClass by omitting `storageClassName` | `manifests/01-postgres.yaml` |
| Postgres | Non-root container could not initialize PVC mount root | `kubectl -n incident-lab logs pod/postgres-0` | Set `PGDATA` to a writable subdirectory inside the mount | `manifests/01-postgres.yaml` |
| Payment | Pod unstable under very low memory limit | `kubectl -n incident-lab describe pod -l app=payment` | Raise memory request and limit | `manifests/03-payment.yaml` |
| Network | `checkout` could not reach `payment` | `kubectl -n incident-lab exec deploy/checkout -- wget -q -O- --timeout=5 http://payment:8080/` | Change allowed source label to `app=checkout` | `manifests/06-networkpolicies.yaml` |
| Controller | Status ConfigMap did not update after feature flag changes | `kubectl -n incident-lab logs deploy/flag-controller` | Add RBAC `watch`; make reconcile loop retry API errors | `manifests/07-controller.yaml` |
| Ingress | Traefik route did not return HTTP 200 | `kubectl -n incident-lab describe ingressroute frontend` | Use same-namespace middleware reference | `manifests/08-ingress.yaml` |

## Verification Commands

```bash
kubectl -n incident-lab get pods,pvc
kubectl -n incident-lab exec deploy/checkout -- wget -q -O- --timeout=5 http://payment:8080/
kubectl -n incident-lab patch configmap feature-flags --type merge -p '{"data":{"ping":"manual"}}'
kubectl -n incident-lab get configmap flag-controller-status -o yaml
curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:30080/
./verify.sh
```

## Expected End State

```text
checkout          Running
flag-controller   Running
frontend          Running
payment           Running
postgres-0        Running
redis             Running
data-postgres-0   Bound
```
