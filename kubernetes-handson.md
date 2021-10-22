
# Kubernetes Hands-On

* [Preparation](#preparation)
* [Deploy the Application](#deploy-the-application)
* [Inspect the State of your Cluster](#inspect-the-state-of-your-cluster)
* [Scale your Application](#scale-your-application)
* [Inspect Probes](#inspect-probes)
* [Inspect Liveness Probe](#inspect-liveness-probe)
* [Inspect Readiness Probe](#inspect-readiness-probe)
* [Advanced Exercises](#advanced-exercises)
* [Cleanup](#cleanup)

---
## Preparation

Please ensure you have completed everything in [`prep.md`][prep.md] before the begin of the
workshop.

[prep.md]: ./prep.md

### Cluster Creation

> For those who took part in Code&Climb or the UCC workshop, please make sure that your previous clusters are no longer running, and that your previous registries have been removed. Feel free to ask if you have question on how to do this.


From this point onward we are documenting stuff for the day of the workshop itself. You do not need to execute this before hand.

In order to create a cluster with the appropriate number of nodes and the Kubernetes version we desire, please execute the following in your virtual machine:

```bash
./setup.lua
```

### Access the Kubernetes Dashboard

Launch a proxy using:

```bash
kubectl proxy > /dev/null &
```

This allows you to access a Kubernetes dashboard under:

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/.
```

Once you are on this page, you will be required to log in. Select the "token" option and paste the token returned from the following command into the text field:

```bash
./setup.lua token
```

Play around with the dashboard and investigate the interesting information it can provide you. Note that we have not yet deployed any application.


### Redis installation
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

## Inspect the State of your Cluster

Check how many pods run in your namespace, and how many of these are from the `sample-app`.

<details>
  <summary>Solution</summary>

Get the pods in the namespace:

```
$ kubectl get pods -n demo
NAME                          READY   STATUS        RESTARTS   AGE
cache-redis-cluster-1         1/1     Running       2          3d
cache-redis-cluster-0         1/1     Running       2          3d
sample-app-6474fffc85-fbfg8   1/1     Running       1          2d9h
cache-redis-cluster-2         1/1     Running       1          2d9h
sample-app-6474fffc85-p552d   0/1     Terminating   1          2d9h
```

There are 3 pods for Redis, and only one for `sample-app`.

</details>

Now check the replica count on the deployment of `sample-app`.

<details>
  <summary>Solution</summary>

We get the deployment names:

```
$ kubectl get deployments -n demo 
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
sample-app   1/1     1            1           3d
```

Then we can describe the deployment:

```
$ kubectl describe deployment sample-app -n demo
Name:                   sample-app
Namespace:              user-0
CreationTimestamp:      Sun, 26 Sep 2021 13:32:56 +0200
Labels:                 app.kubernetes.io/managed-by=Helm
Annotations:            deployment.kubernetes.io/revision: 1
                        meta.helm.sh/release-name: sample-app
                        meta.helm.sh/release-namespace: user-0
Selector:               app.kubernetes.io/instance=sample-app,app.kubernetes.io/name=sample-app
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app.kubernetes.io/instance=sample-app
           app.kubernetes.io/name=sample-app
  Containers:
   sample-app:
    Image:      f4z3r/sample-app:0.1.0
    Port:       8080/TCP
    Host Port:  0/TCP
    Limits:
      cpu:     200m
      memory:  256Mi
    Requests:
      cpu:     100m
      memory:  128Mi
    Environment:
      REDIS_PW:        <set to the key 'redis-password' in secret 'cache-redis-cluster'>  Optional: false
      REDIS_BASE_URL:  cache-redis-cluster
    Mounts:            <none>
  Volumes:             <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   sample-app-5795dc79d8 (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  20m   deployment-controller  Scaled up replica set sample-app-5795dc79d8 to 1
```

We can see under `replicas` that we have a single desired replica, and that one is available.

</details>

## Scale your Application

An application with one replica is not highly available. If the pod crashes, your application is down until Kubernetes has managed to launch a new pod. Let us scale the application to 3 replicas.
You can try to scale your application via the deployment or via helm. Try both solutions.

<details>
  <summary>Solution</summary>

A) Using the `scale` command:

```
$ kubectl scale deployment sample-app --replicas=3 -n demo
deployment.apps/sample-app scaled
```

B) Using the `helm` command:

Get a list of helm releases
```
$ helm list -n demo
NAME      	NAMESPACE	REVISION	UPDATED                                 	STATUS  	CHART              	APP VERSION
cache     	demo     	1       	2021-10-17 23:40:23.099179648 +0200 CEST	deployed	redis-cluster-6.3.8	6.2.5      
sample-app	demo     	1       	2021-10-17 23:41:31.473573563 +0200 CEST	deployed	sample-app-0.1.0   	0.1.0 
```
Get the possible values for your chart
```
$ helm get values sample-app --all -n demo

COMPUTED VALUES:
image:
  pullPolicy: IfNotPresent
  repository: f4z3r/sample-app
  tag: 0.1.0
redis_release_name: cache
replicaCount: 1
```
Patch the helm release
```
$ cd sample-app
$ helm upgrade sample-app . --reuse-values --set replicaCount=3 -n demo

Release "sample-app" has been upgraded. Happy Helming!
NAME: sample-app
LAST DEPLOYED: Thu Oct 21 00:54:35 2021
NAMESPACE: demo
STATUS: deployed
REVISION: 3
TEST SUITE: None
NOTES:
Your sample application was deployed.
```

Let us check the pods again:

```
$ kubectl get pods -n demo
NAME                          READY   STATUS    RESTARTS   AGE
cache-redis-cluster-1         1/1     Running   2          3d
cache-redis-cluster-0         1/1     Running   2          3d
sample-app-6474fffc85-fbfg8   1/1     Running   1          2d9h
cache-redis-cluster-2         1/1     Running   1          2d10h
sample-app-6474fffc85-2zxvc   1/1     Running   0          49s
sample-app-6474fffc85-swpml   1/1     Running   0          49s
```

We can see we 3 pods of the demo-app running now.

</details>

## Inspect Probes

Currently, as soon as the container of our application is started, it is assumed to be running and ready to serve requests. This is not the case in real life. We will configure liveness and readiness probes. But first, figure out what could be the dependency for the readiness probe. You can inspect
the code that is running on the cluster in [`assets/main.go`][main.go].

[main.go]: assets/main.go

Further information: [Probes, official documentation][probes].

[probes]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

<details>
  <summary>Solution</summary>

The readiness probe determines when the server can accept incoming requests, and process them. In the case of our application, we can see in the code that is uses Redis as a persistence layer. If it cannot contact Redis, it cannot serve requests, and should therefore not be marked as `Ready`. Specifically, we can see this in the readiness probe implementation of the application:

```go
http.HandleFunc("/readiness", func(w http.ResponseWriter, r *http.Request) {
    err := rdb.ForEachShard(ctx, func(ctx context.Context, shard *redis.Client) error {
        return shard.Ping(ctx).Err()
    })

    if err != nil {
       http.Error(w, "not ready yet!", 500) 
    } else {
        fmt.Fprint(w, "ready!\n")
    }
})
```

You can see here that if the application cannot contact each Redis shard (via a ping), it will return an error, marking it as "not ready". This makes sense as not being able to contact a shard implies it might not be able to serve a request.

</details>

## Inspect Liveness Probe

Inspect the liveness probe in the deployment. You can find it the deployment spec.

<details>
  <summary>Solution</summary>


```bash
kubectl get deployment sample-app -n demo
```

Under `spec.template.spec.containers[0]` you can find the following lines:

```yaml
livenessProbe:
  httpGet:
    path: /liveness
    port: 8080
  initialDelaySeconds: 1
  periodSeconds: 3
```
The endpoint for the probe is `/liveness` and the server runs on port `8080`. It will check every 3 seconds with an initialDelay of 1 second.

</details>

## Inspect Readiness Probe

Inspect the readiness probe in the deployment. You can find it the deployment spec.

<details>
  <summary>Solution</summary>

```bash
kubectl get deployment sample-app -n demo
```

Under `spec.template.spec.containers[0]` you can find the following lines:

```yaml
readinessProbe:
  httpGet:
    path: /readiness
    port: 8080
  initialDelaySeconds: 2
  periodSeconds: 3
```

The endpoint for the probe is `/readiness` and the server runs on port `8080`. It will check every 3 seconds with an initialDelay of 1 second.

</details>

## Advanced Exercises

### Scale down redis
Scale down your redis nodes from 3 to 2. Inspect what is happening to the sample-app. Why is this happening?
<details>
  <summary>Solution</summary>

```bash
$ kubectl scale statefulset cache-redis-cluster --replicas=2 -n demo
statefulset.apps/cache-redis-cluster scaled
```

```bash
$ kubectl get pods -n demo
NAME                        READY   STATUS    RESTARTS   AGE
cache-redis-cluster-1       1/1     Running   2          3d1h
cache-redis-cluster-0       1/1     Running   2          3d1h
sample-app-554796cf-wfsc4   0/1     Running   0          8m
sample-app-554796cf-vbrtj   0/1     Running   0          7m57s
sample-app-554796cf-gggqw   0/1     Running   0          7m19s
```

You can see here that if the application cannot contact each Redis shard (via a ping), it will return an error, marking it as “not ready”. This makes sense as not being able to contact a shard implies it might not be able to serve a request.

Let's fix it:
```
$ kubectl scale statefulset cache-redis-cluster --replicas=3 -n demo
statefulset.apps/cache-redis-cluster scaled
```

</details>

### Change the url of your application
You are able to access you app in the Broswer via http://sample-app.localhost:9080/my-key. Try to make it available on http://yourname-sample-app.localhost:9080/my-key. Hint: you have to update your ingress resource.

<details>
  <summary>Solution</summary>

```bash
$ kubectl get ingress -n demo
NAME         CLASS    HOSTS                  ADDRESS                                       PORTS   AGE
sample-app   <none>   sample-app.localhost   172.19.0.3,172.19.0.4,172.19.0.5,172.19.0.6   80      17m
```
Open the ingress in edit mode:
```bash
$ kubectl edit ingress sample-app -n demo
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    meta.helm.sh/release-name: sample-app
    meta.helm.sh/release-namespace: demo
  creationTimestamp: "2021-10-20T23:12:21Z"
  generation: 3
  labels:
    app.kubernetes.io/instance: sample-app
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: sample-app
    app.kubernetes.io/version: 0.1.0
    helm.sh/chart: sample-app-0.1.0
  name: sample-app
  namespace: demo
  resourceVersion: "30102"
  uid: bc3c8dff-48ab-4b46-a2ee-35321d4c94e3
spec:
  rules:
  - host: sample-app.localhost
    http:
      paths:
      - backend:
          service:
            name: sample-app
            port:
              number: 80
        path: /
        pathType: Prefix
status:
  loadBalancer:
    ingress:
    - ip: 172.19.0.3
    - ip: 172.19.0.4
    - ip: 172.19.0.5
    - ip: 172.19.0.6
```

Under `spec.rules.host` you will find the advertised host. Change it you your new hostname. Save the changes.

Test if you can reach your application with the new hostname.

</details>

### Find out the redis password
Find out the password of your redis instance. Hint: It's a secret.

<details>
  <summary>Solution</summary>

Get a list of all secrets in your namespace:
```bash
$ kubectl get secrets -n demo
NAME                               TYPE                                  DATA   AGE
default-token-6pg9n                kubernetes.io/service-account-token   3      3d2h
cache-redis-cluster                Opaque                                1      3d2h
sh.helm.release.v1.cache.v1        helm.sh/release.v1                    1      3d2h
sh.helm.release.v1.sample-app.v1   helm.sh/release.v1                    1
```
Open the redis secret:
```bash
 kubectl get secret cache-redis-cluster -oyaml -n demo
```

```yaml
apiVersion: v1
data:
  redis-password: XXXYYYZZZ==
kind: Secret
metadata:
  annotations:
    meta.helm.sh/release-name: cache
    meta.helm.sh/release-namespace: demo
  creationTimestamp: "2021-10-17T21:40:23Z"
  labels:
    app.kubernetes.io/instance: cache
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis-cluster
    helm.sh/chart: redis-cluster-6.3.8
  name: cache-redis-cluster
  namespace: demo
  resourceVersion: "13101"
  uid: 6a1e7b9e-92aa-4c07-9749-b792c63ea800
type: Opaque
```
The password is base64 encoded, decode it:
```bash
$ echo "XXXYYYZZZ=="|base64 -d && printf "\n"
yourPassword
```

</details>

## Cleanup

In order to free some resources on your machine, delete the demo namespace:

```bash
$ kubectl delete namespace demo
namespace "demo" deleted
```
