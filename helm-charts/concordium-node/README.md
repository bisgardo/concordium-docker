# Helm chart: concordium-node

A basic chart for deploying a node with a collector in a Kubernetes cluster.
The two applications run in different containers within the same pod using a `statefulset` and a `service`.
An init container copies the genesis data file on startup into a persistent volume belonging to the pod.

No `ingress` is being set up because the endpoints are not HTTP based.

The chart has been verified to work (with 1 and 2 replicas) in [minikube](https://minikube.sigs.k8s.io/docs/) v1.22.0 on Ubuntu 20.04.

*Missing features*

- There is no mechanism for injecting baker credentials.
- Multiple replicas are not well-supported:
  It works but there is no mechanism for configuring them differently
  (e.g., different node names).
- The chart contains no tests.

## Prerequisites

Some of the following will have to be set up for the chart to start running successfully.
It's not important to do any of it before installing the chart
as Kubernetes will just wait for the relevant resources to be present.

The node depends on a configmap holding the genesis data file.
Install using the following command, executed from the project root:

```shell
kubectl create configmap genesis --from-file=testnet=./genesis/testnet-0.dat --from-file=mainnet=./genesis/mainnet-0.dat
```

If running with a "lesser managed" Kubernetes cluster, the persistent volume might need to be created manually.
The example PV spec in `local-persistentvolume.yaml` may be setup using

```shell
kubectl apply -f ./local-persistentvolume.yaml
```

In the case of Minikube, there is an addon `storage-provisioner` that enables automatic provisioning; enable using

```shell
minikube addons enable storage-provisioner
```

## Install

Install or upgrade the chart as release name `concordium-node` using the command

```shell
helm upgrade --install concordium-node . --set=node.name=<name> --set=network=<network>
```

where `<name>` is the name of the node to be presented on the
[public dashboard](https://dashboard.mainnet.concordium.software/)
(set to empty to disable the collector container)
and `<network>` is `testnet` or `mainnet`.

Also consider overriding the image repositories (using `--set` or a custom values file).
See [values.yaml](./values.yaml) (e.g. using `helm show values .`)
for the default values and a full list of overridable fields.

## Test

Once installed, a test may be run on the release to verify that it's running:

```shell
helm test concordium-node
```

## Uninstall

```shell
helm uninstall concordium-node
```
