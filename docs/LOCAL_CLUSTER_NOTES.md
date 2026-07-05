# Local Cluster Notes

These notes document what happened in the verified local environment. They are included
because they are realistic DevSecOps conditions, not because they are part of the five
original lab bugs.

## Cluster Context

The lab was verified on an existing kind-based cluster that already had:

- Kyverno admission policies
- local-path dynamic provisioning
- Traefik installed through Helm
- no Docker host port mapping for Traefik NodePort `30080`

## Kyverno

The cluster enforced:

- non-root pods
- CPU and memory limits

The application manifests were hardened to satisfy those policies instead of bypassing
admission.

Traefik also needed resource limits during Helm installation:

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

## local-path Provisioner

The default StorageClass was valid, but local-path helper pods were initially blocked by
the same Kyverno policies. The provisioner was made policy-compliant in the live cluster
so Postgres PVC provisioning could complete.

This was an environment prerequisite, not a change to the lab grader.

## Traefik Access

The active kind cluster did not publish container port `30080` to host port `30080`.
Because `verify.sh` curls `http://localhost:30080/`, the verified workaround was:

```bash
kubectl -n traefik port-forward --address 127.0.0.1 service/traefik 30080:80
```

For a clean fresh cluster, prefer creating kind with `extraPortMappings` as shown in the
main `README.md`.

## Controller API Path

The local cluster intermittently timed out on pod-to-Kubernetes-service API calls during
verification. The controller was kept portable by using the standard in-cluster
Kubernetes service environment variables and retrying API errors instead of exiting.

This is documented because it is a real operational issue observed during verification:
controller logic must tolerate API timeouts and keep reconciling.
