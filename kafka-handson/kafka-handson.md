# Kafka Hands-On

* [Deploy the Operator](#deploy-the-operator)
* [Deploy Kafka](#deploy-kafka)
* [Scale up](#scale-up)
* [Run a producer and consumer](#run-a-producer-and-consumer)
* [Install additional platform components](#install-additional-platform-components)

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

<details>
  <summary>Solution</summary>

Verify that the zookeeper pod is running:

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

Then install the kafka broker. This may also take a few minutes. Also verify if it is are running.

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

## Run a producer and consumer

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

## Install additional platform components

Now let's install connect, the schema registry and control center.

<details>
  <summary>Solution</summary>

```bash
kubectl apply -f schemaregistry.yaml -n operator
kubectl apply -f connect.yaml -n operator
kubectl apply -f controlcenter.yaml -n operator
```

</details>