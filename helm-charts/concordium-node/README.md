# Helm chart: concordium-node

A very basic chart for deploying a node with a collector in a Kubernetes cluster.
The two applications run in different containers in the same pod using a `deployment` and a `service`.
An init container copies the genesis data file on startup into an ephemeral volume belonging to the pod.

No `ingress` is being set up because the endpoints are not HTTP based.

*Missing features*

- There is no mechanism for injecting baker credentials.
- No persistent storage is being set up atm.
- Given that the node is stateful (once persistent storage is added),
  a `statefulset` would probably be a better match than a `deployment`.

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
