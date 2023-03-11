# Metrics

## Prometheus

The Concordium Node exposes a few metrics directly as a [Prometheus](https://prometheus.io/) scrape endpoint.

### Node configuration

The relevant configuration properties are:

- `--prometheus-listen-addr` (env: `CONCORDIUM_NODE_PROMETHEUS_LISTEN_ADDRESS`):
  IP on which to register the endpoint.
  The default value is `127.0.0.1` which doesn't expose the endpoint externally (not even to the host when running in a Docker container).
  To enable incoming requests, set this propertySet to `0.0.0.0`.

- `--prometheus-listen-port` (env: `CONCORDIUM_NODE_PROMETHEUS_LISTEN_ADDRESS`):
  Port on which to register the endpoint. Defaults to `9090`.

### Prometheus configuration

The file [`./prometheus.yml`](./prometheus.yml) configures a Prometheus instance to scrape
itself on `localhost` port `9090` and a single node on host `node` and also port `9090`.
This configuration matches the network of the [Docker Compose deployment](../README.md#build-andor-run-using-docker-compose])
and is the configuration used when the profile `prometheus` is activated in the deployment.

Data collected by Prometheus is accessed using the [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/) query language,
either through Prometheus' own web UI or as a data source to a separate visualization tool like Grafana.

## Grafana

Grafana is an extremely powerful tool for visualizing all kinds of data from all kinds of sources in all kinds of ways.

The [download page](https://grafana.com/grafana/download?edition=oss) explains how to install Grafana
natively on the host or in Docker.
For reference, a simple command for running the latest version in Docker on port 3000 is

```shell
docker run -d --name=grafana -p 3000:3000 grafana/grafana-oss
```

Use `docker stop grafana` and `docker start grafana` to start and stop the service.

### Dashboard

The file [`./grafana-dashboard.json`](./grafana-dashboard.json) contains an export of a trivial dashboard
with a single a panel that shows a metric as a simple time/value graph.
The panel is repeated over all metric names using a hidden variable containing all metric names,
so the panels cannot be edited individually.

To use the dashboard, first add a Prometheus data source with HTTP URL `http://<host>:9009`,
where `<host>` is the host that Prometheus is running on.
In a local setup, this is usually `localhost` or `172.17.0.1` depending on whether *Grafana* is running in Docker.

With the data source in place, the dashboard may be imported as follows:
1. Click the "+ Import" on the "Dashboards" menu in the sidebar to go to the "Import dashboard" page.
2. Drag/drop the JSON file onto the marked area of the page and give the dashboard a proper name. Then click "Import".
