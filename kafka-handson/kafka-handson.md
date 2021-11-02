# Kafka Hands-On

* [Deploy the Operator](#deploy-the-operator)
* [Deploy Kafka](#deploy-kafka)
* [Scale up](#scale-up)
* [Configure Node-affinity](#node-affinity)
* [Run a Producer and Consumer](#run-a-producer-and-consumer)
* [Describe a Topic](#describe-a-topic)
* [Deploy Connect and a Connector](#deploy-connect-and-a-connector)
* [Deploy Control Center](#deploy-control-center)
* [Deploy Schema Registry](#deploy-the-schema-registry)

In this hands-on, we will deploy Confluent for Kubernetes, which is a Kubernetes native Kafka operator. For more information, go to the official documentation: https://docs.confluent.io/operator/current/overview.html


## Deploy the Operator

First, we will create a namespace in which the Kafka Platform should run.

Create a namespace called "operator".

<details>
  <summary>Solution</summary>

```bash
kubectl create namespace operator
```

</details>

Then we will deploy the operator.

```bash
helm upgrade --install --values operator-values.yaml --namespace operator operator confluent-for-kubernetes-2.1.0/helm/confluent-for-kubernetes
```

Check if the operator pod is running.

<details>
  <summary>Solution</summary>

```bash
kubectl get pods -n operator
```

You should see a pod running similar to this one:

```
NAME                                  READY   STATUS    RESTARTS   AGE
confluent-operator-5699dd58f7-sfgkx   1/1     Running   0          37s
```

You can also see your operator pod in the Kubernetes Dashboard:

http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/pod?namespace=operator

</details>

## Deploy Kafka

Now that the operator is running, it will react if a new custom resource file is applied to the cluster and will create or update resources as declared.

Install Zookeeper:

```bash
kubectl apply -f zookeeper.yaml -n operator
```

Verify that the zookeeper pod is running.

<details>
  <summary>Solution</summary>

```bash
kubectl get pods -n operator
```

This should return a result similar to this one (It may take a few minutes until they are up):

```
NAME                                  READY   STATUS            RESTARTS   AGE
confluent-operator-5699dd58f7-sfgkx   1/1     Running           0          20m
zookeeper-0                           1/1     Running           0          13m
```

</details>

Then install the kafka broker. This may also take a few minutes. Also verify if it is running.

<details>
  <summary>Solution</summary>

```bash
kubectl apply -f kafka.yaml -n operator
```

</details>

## Scale up

One kafka broker is not very resilient. If it dies, there is no other one that could still serve clients. Let's scale up to three brokers!

<details>
  <summary>Solution</summary>

Edit the file `kafka.yaml` to increase the replicas.

```yaml
...
spec:
  replicas: 3
...
```

Then apply the changed file to the Kubernetes cluster:

```bash
kubectl apply -f kafka.yaml -n operator
```

Verify that two new kafka pods are created.

```bash
kubectl get pods -n operator
```

</details>

## Configure Node affinity
Kafka as a distributed message queue has some requirements regarding node placement if you want to be sure you don't run into any issues on your productive environment. One of those requirements is that each kafka broker runs on a seperate node. You should acutally do the same for zookeeper, and ensure that the zookeepers also run on different nodes than the broker itself. Since we are limited with our local setup, we will just ensure that zookeeper and brokers run on one of the 3 nodes each.


First, check how your brokers are actually distributed on the nodes:
```bash
kubectl get po -n operator -o wide
```
You will see that two brokers share the same node (or you are just lucky it placed them initially correct :-))

The Confluent Operator makes it easy to define that there is only one broker per node, simply by setting the following config:

```yaml
...
spec:
  oneReplicaPerNode: true
...
```

-> Now apply this for zookeeper and kafka.
Note: you might have to delete zookeeper/kafka first in order to get it to work. You can try updating it first though.

If you apply this configuration, you will see that each instance of zookeeper/kafka is on a differnet node.

If you now check again where the pods are located, you will notice something else that might not be desired:
```bash
kubectl get po -n operator -o wide
```

Some of the Pods might be on the master node of kubernetes. that should not be the case. To fix this, you can use node affinities to explicitly tell kubernetes where to place (or not place) the pods.
Read more about it here: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/

<details>
  <summary>Solution</summary>

First you should check how your kubernetes nodes are labelled:
```bash
kubectl get nodes -o wide
kubectl describe node k3d-ievent-server-0
```

-> You will see for instance the following under Labels: `kubernetes.io/hostname=k3d-ievent-server-0`
Remember, this is the node that shouldn't be used for our pods. We can add now the following code:


```yaml
...
spec:
  podTemplate:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/hostname
              operator: NotIn
              values:
              - k3d-ievent-server-0
...
```
With this we tell kubernetes to NOT schedule the pod on the node with the label `kubernetes.io/hostname=k3d-ievent-server-0`
If you apply this now for zookeeper and kafka, the pods should be distributed correctly.
Note: also here, you might first have to delete the deployment complelety and reapply it, as it might not work with an update due to very limtied resources.

</details>

## Run a Producer and Consumer

First, create a topic:

```bash
kubectl apply -f my-first-topic.yaml -n operator
```

Verify it has been created:

```bash
kubectl get kafkatopics -n operator
```

This should return a result similar to this one:

```
NAME             REPLICAS   PARTITION   STATUS    CLUSTERID                AGE
my-first-topic   3          6           CREATED   wJQw6LTUQ6CRgABPP_QoTA   12s
```

Deploy a kafka client pod that has kafkacat installed, a nice utility to interact with kafka.

```bash
kubectl apply -f kafkacat.yaml -n operator
```

Produce a few messages to Kafka from this pod.

```bash
kubectl -n operator exec -it kafkacat -- bash 

$ kafkacat -P -b kafka:9071 -t my-first-topic
```

Then, consume the messages you just produced.

<details>
  <summary>Solution</summary>

```bash
$ kafkacat -C -b kafka:9071 -t my-first-topic -o beginning -q
```

If you leave away `-o beginning`, the consumer will read starting from its last consumed offset.
`-q` stands for quiet mode and suppresses additional information.

</details>

Bonus Task:

Produce the numbers 1-10 to your topic, and then consume them. What is happening here?

<details>
  <summary>Solution</summary>

Do you observe that the numbers where not consumed in the same sequence as you produced them? This behaviour is expected! Kafka guarantuees ordering of messages only within a partition, but not within a topic. If a topic has multiple partitions (and no custom partitioning is defined), the messages will be written to partitions round-robin. While reading, the messages will not necessarily be consumed in the same order. If you need to guarantee total ordering on topic-level, you need to configure the topic with only 1 partition. Only do that if you really need to, since it limits your possibilities to scale your consumers.

</details>

## Describe a Topic

The kafka binaries come with many tools to interact with Kafka. For now, we use the kafka binaries that are installed on the kafka brokers, but usually, you would install the kafka binaries on your local computer and connect to the cluster from there. Here you can download Kafka and find documentation: https://kafka.apache.org/downloads

But for now, we go directly into one Kafka broker and get topic metadata from there.

First, open a bash shell in one of the kafka pods.

<details>
  <summary>Solution</summary>

```bash
kubectl -n operator exec -it kafka-0 -- bash 

```

</details>

Then describe the topic `my-first-topic` using the CLI tool `kafka-topics`.

<details>
  <summary>Solution</summary>

```bash
kafka-topics --describe --topic my-first-topic --bootstrap-server kafka:9071
```

</details>

Discuss the results with your neighbour. What do they mean?


## Deploy Connect and a Connector

Install connect and wait until it is fully up.

<details>
  <summary>Solution</summary>

```bash
kubectl apply -f connect.yaml -n operator
```

</details>

Then, deploy the connector `my-first-connector`.

Since the newest version of Confluent for Kubernets (2.1.0), connectors can now also be deployed as custom resources.

<details>
  <summary>Solution</summary>

```bash
kubectl apply -f my-first-connector.yaml -n operator
```

</details>

Study the connector configs in the yaml and discuss with your neighbour what the connector does.

<details>
  <summary>Solution</summary>

The connector is a sink connector, which means that it writes data from a kafka topic to another system.
It is a file sink connector, and simply writes the contents of the topic `my-first-topic` to a file named `/tmp/test-sink.txt` in the connect pod.

</details>

Look at the file and verify that the data you produced to the topic with kafkacat arrived at the sink.

<details>
  <summary>Solution</summary>

```bash
kubectl -n operator exec -it connect-0 -- bash

$ cd ../../tmp
$ cat test-sink.txt
```

</details>

## Deploy Control Center

Control Center is Confluent's commercial UI for the Kafka Platform.

Install it and wait until its fully up.

<details>
  <summary>Solution</summary>

```bash
kubectl apply -f controlcenter.yaml -n operator
```

</details>

To access it, you will have to complete the step "Expose Controlcenter as ingress"

## Deploy Schema Registry

(Optional) Install the schema registry and make yourself familiar with it.

<details>
  <summary>Solution</summary>

```bash
kubectl apply -f schemaregistry.yaml -n operator
```

You can find documentation about the schema registry here: https://docs.confluent.io/platform/current/schema-registry/index.html

</details>


## Expose Controlcenter as ingress

As you have learned from the kubernetes hands-on part, you will have to create an ingress to expose a service if you want to reach it via HTTP(S). Controlcenter is the WebUI of the Confluent platform and it would therefore be nice if we could access it with our browser, right? ;-)

Try to create an ingress similar to the one you created for the sample-app. Note that you have to use the correct service for this (Execute `kubectl get svc -n operator` and check which of the services has an IP and is for Controlcenter). Also, check which Port you have to use! It's not a default Port.

<details>
  <summary>Solution</summary>

```yaml
...
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: controlcenter
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: controlcenter-0-internal
            port:
              number: 9021
...
```
</details>

After applying the ingress, you should be able to browse to your controlcenter with `localhost:9080`.
You will find monitoring information about your topic `my-first-topic` and your connector `my-first-connector`.
