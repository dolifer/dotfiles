# Running Kubernetes locally

## Dashboard

### Deploy

```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
```

### Proxy

```shell
kubectl proxy
```

Kubectl will make Dashboard available at http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/.

### Get token

```shell
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | awk '/^deployment-controller-token-/{print $1}') | awk '$1=="token:"{print $2}'
```

## Expose deployment

This makes the service `my-svc` available on host port 8081 and requests will be proxied to port 8080 of the pod's.

```shell
kubectl expose deployment my-svc --type=LoadBalancer --port 8081 --target-port=8080
```
