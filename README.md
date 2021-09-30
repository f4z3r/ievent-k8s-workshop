# iEvent Kubernetes and Kafka Workshop 

## Preparation

Please ensure you have completed everything in [`prep.md`][prep.md] before the begin of the
workshop.

[prep.md]: ./prep.md

## Cluster Creation

> For those who took part in Code&Climb or the UCC workshop, please make sure that your previous
> clusters are no longer running, and that your previous registries have been removed. Feel free to
> ask if you have question on how to do this.


From this point onward we are documenting stuff for the day of the workshop itself. You do not need
to execute this before hand.

In order to create a cluster with the appropriate number of nodes and the Kubernetes version we
desire, please execute the following in your virtual machine:

```bash
./setup.lua
```

## Access the Kubernetes Dashboard

Launch a proxy using:

```bash
kubectl proxy > /dev/null &
```

This allows you to access a Kubernetes dashboard under:

```
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/.
```

Once you are on this page, you will be required to log in. Select the "token" option and paste the
token returned from the following command into the text field:

```bash
./setup.lua token
```

Play around with the dashboard and investigate the interesting information it can provide you. Note
that we have not yet deployed any application.
