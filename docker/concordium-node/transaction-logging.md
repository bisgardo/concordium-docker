# Transaction logging

The Concordium Node includes the ability to
[log transactions to an external PostgreSQL database](https://github.com/Concordium/concordium-node/blob/main/docs/transaction-logging.md).
Due to various shortcomings, this feature is now deprecated in favor of an equivalent
[independent service](https://github.com/Concordium/concordium-transaction-logger):
The service is deployed separately, handles errors gracefully,
and may run against multiple nodes that don't need any particular configuration or state.
The DB schemas are documented in the links above.
This project used to support the legacy method, but this was removed in commit `6933166`.

The Docker Compose file includes a transaction logger instance under the profile `txlog`.
The [image](https://hub.docker.com/r/concordium/transaction-logger/tags) is specified with the variable `TRANSACTION_LOGGER_IMAGE`.

Database credentials etc. are configured with the following variables:

- `TXLOG_PGDATABASE` (default: `concordium_txlog`): Name of the database in the PostgreSQL instance created for the purpose.
- `TXLOG_PGHOST` (default: `172.17.0.1`): DNS or IP address of the host.
  The default value assumes that the PostgreSQL instance is running natively, i.e. outside of Docker.
- `TXLOG_PGPORT` (default: `5432`): Port of the PostgreSQL instance.
- `TXLOG_PGUSER` (default: `postgres`): Username of the PostgreSQL user used to log the transactions.
- `TXLOG_PGPASSWORD`: Password of the PostgreSQL user.

The variables may be passed to the `docker-compose` command above or persisted in a `.env` file as described below
(see [`testnet+txlog.env`](./testnet+txlog.env) and [`mainnet+txlog.env`](./mainnet+txlog.env);
note that `TXLOG_PGPASSWORD` still has to be passed explicitly).

## Setting up local PostgreSQL instance

One way to deploy the database is to include it as an extra service in the Docker Compose file
(might be included under a specific profile in the future).

This is probably the easiest solution as the DB is then already on the same network as the Node.
It will also be directly "namespaced" to the project, avoiding interference between data from testnet and mainnet.

However, because of the strict availability requirements mentioned above, it may be preferable to run it separately,
either natively on the host or in another Docker (Compose) setup.

## Installing on Ubuntu (like) host

In case native deployment of the database is preferred,
a basic functioning setup on a host running a "recent" version of Ubuntu may be configured as follows:

1. Install version `<version>` of server and `psql` client
   (probably only one or two different versions are available in the public repository -
   it's not important which one is used).
   
   ```shell
   sudo apt update
   sudo apt install postgresql-<version> postgresql-client-<version>
   ```
   
   This also creates the system and DB user `postgres`:

2. Create database with name `<database-name>` and set password `<database-password>` for user `postgres`:
   
   ```shell
   $ sudo -u postgres psql
   # CREATE DATABASE "<database-name>";
   # ALTER USER postgres WITH PASSWORD '<database-password>';
   ```

3. Allow external connections (access from within a Docker container on a non-host network counts as "external").
   
   In `/etc/postgresql/<version>/main/postgresql.conf`, set
   
   ```
   listen_addresses = '*'
   ```

4. Allow password based access to the database via the `postgres` user.
   In `/etc/postgresql/<version>/main/pg_hba.conf`, add the following record:
   
   ```
   host    <database-name>     postgres        all     password
   ```
   
   Use `<database-name>` `all` to allow access to all DBs.

5. Restart the system service:
   
   ```shell
   sudo systemctl restart postgresql.service
   ```

## Installing in Kubernetes

Bitnami's Helm chart provides a very easy way of spinning up a PostgreSQL instance in Kubernetes:

Add the repo and install the chart using the following commands:

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres-txlog --set-string="auth.database=<database-name>,auth.postgresPassword=<database-password>" bitnami/postgresql
```

If needed, forward port 5432 in order to connect to the DB from outside the cluster:

```shell
kubectl port-forward --namespace default svc/postgres-txlog-postgresql 5432:5432
```

Then, in another terminal, connect to the database using for instance `psql`:

```shell
PGPASSWORD="<database-password>" psql --host 127.0.0.1 -U postgres -d <database-name> -p 5432
```

Uninstall using

```shell
helm uninstall postgres-txlog
```

Uninstalling the release doesn't wipe the persisted data of the database:
The persistent volume and accompanying claim has to be deleted manually.
Not doing this may cause subsequent deployments to reuse the old password,
even if a different one was provided to `helm install`.
