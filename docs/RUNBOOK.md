# Runbook

## Objective

Bring the `incident-lab` namespace to a verified healthy state without deleting the
namespace and without modifying `verify.sh`.

## Prerequisites

- `kubectl`
- `kind`
- `helm`
- Traefik CRDs installed before applying `manifests/08-ingress.yaml`

## Deploy

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ports.web.nodePort=30080 \
  --set service.type=NodePort

kubectl -n traefik rollout status deploy/traefik --timeout=120s
kubectl apply -f manifests/
```

If the cluster enforces resource limits on all workloads, install Traefik with limits:

```bash
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ports.web.nodePort=30080 \
  --set service.type=NodePort \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=64Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=256Mi
```

## Verify Workloads

```bash
kubectl -n incident-lab get pods,pvc
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Expected:

```text
all pods       1/1 Running
data-postgres-0 Bound
```

## Verify Network

```bash
kubectl -n incident-lab exec deploy/checkout -- \
  wget -q -O- --timeout=5 http://payment:8080/
```

Expected:

```text
payment ok
```

## Verify Controller

```bash
kubectl -n incident-lab get configmap flag-controller-status -o jsonpath='{.data.observed_generation}'
kubectl -n incident-lab patch configmap feature-flags --type merge -p '{"data":{"ping":"manual"}}'
sleep 10
kubectl -n incident-lab get configmap flag-controller-status -o jsonpath='{.data.observed_generation}'
```

Expected: the value changes.

## Verify Ingress

If kind exposes host port `30080`:

```bash
curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:30080/
```

If not, run this in another terminal:

```bash
kubectl -n traefik port-forward --address 127.0.0.1 service/traefik 30080:80
```

Expected:

```text
200
```

## Final Grader

```bash
./verify.sh
```

Expected:

```text
All checks passing. Incident resolved.
```

## Fast Triage Commands

```bash
kubectl -n incident-lab describe pvc data-postgres-0
kubectl -n incident-lab describe pod -l app=payment
kubectl -n incident-lab describe netpol allow-payment-from-checkout
kubectl -n incident-lab logs deploy/flag-controller --tail=100
kubectl -n incident-lab describe ingressroute frontend
```
