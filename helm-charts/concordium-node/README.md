# Helm chart: concordium-node

A basic chart for deploying a node with a collector in a Kubernetes cluster.
The two applications run in different containers within the same pod using a `statefulset` and a `service`.
An init container copies the genesis data file on startup into a persistent volume belonging to the pod.

No `ingress` is being set up because the endpoints are not HTTP based.

The chart has been verified to work (with 1 and 2 replicas) in [minikube](https://minikube.sigs.k8s.io/docs/) on Linux.

*Missing features*

- There is no mechanism for injecting baker credentials.
- Multiple replicas are not well-supported:
  It works but there is no mechanism for configuring them differently
  (e.g., different node names).
- The chart contains no tests.

## Install

```shell
helm install concordium-node . --set nodeName=<name>
```

where `<name>` is the name of the node to be presented on the
[public dashboard](https://dashboard.mainnet.concordium.software/)
(set to empty to disable the collector container).

Also consider overriding the image repositories (using `--set` or a custom values file).
See [values.yaml](./values.yaml) (e.g. using `helm show values .`)
for the default values and a full list of overridable fields.

## Uninstall

```shell
helm uninstall concordium-node
```
