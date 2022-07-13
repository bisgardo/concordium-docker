# Metrics

The node exposes a few metrics as a [Prometheus](https://prometheus.io/) scrape endpoint on port `9090`.
If profile `prometheus` is enabled, a Prometheus [instance](https://hub.docker.com/r/prom/prometheus)
that is configured to scrape itself and the node (see [prometheus.yml](prometheus.yml) for the configuration)
is started as well.
The web UI of that service is exposed to the host on port `9009`.
