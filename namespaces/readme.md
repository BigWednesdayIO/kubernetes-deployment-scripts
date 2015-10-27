# Namespaces for Kubernetes cluster
http://kubernetes.io/v1.0/docs/admin/namespaces/README.html

## Creating namespaces

``` shell
kubectl create -f dev-namespace.yaml
```

``` shell
kubectl create -f prd-namespace.yaml
```

## View namespaces

``` shell
kubectl get namespaces
```

## Use namespaces
Create kubectl context for namespace, get cluster and namespace by running `kubectl config view`

``` shell
kubectl config set-context dev --namespace=development --cluster=<cluster> --user=<user>
```

``` shell
kubectl config set-context prd --namespace=production --cluster=<cluster> --user=<user>
```

Change context

```shell
kubectl config use-context dev
```
