# Kubernetes Hands-On

## Preparation

Get the Helm chart repository for Redis:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

and install a Redis cluster:

```bash
kubectl create ns demo
helm install -n demo cache bitnami/redis-cluster \
  --set "cluster.nodes=3" \
  --set "cluster.replicas=0" \
  --set "cluster.update.currentNumberOfNodes=3"
```

## Deploy the Application

```bash
helm install -n demo sample-app ./sample-app
```

Check that the application works:

```bash
curl -X PUT -d 'some data' sample-app.localhost:9080/my-key
# you can also just open the URL in your browser
curl sample-app.localhost:9080/my-key
```

## Scale the Application

