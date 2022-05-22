# Transaction logging (legacy)

The Concordium Node includes the ability to
[log transactions to an external PostgreSQL database](https://github.com/Concordium/concordium-node/blob/main/docs/transaction-logging.md).
As explained in the disclaimer below,
this method of logging transactions is in the process of being replaced by a separate service.

This feature is disabled by default and may be enabled in the Docker Compose setup by defining the environment variable
`CONCORDIUM_NODE_TRANSACTION_OUTCOME_LOGGING` with any value.

Database credentials etc. are configured with the following variables:

- `TXLOG_PGDATABASE` (default: `concordium_txlog`): Name of the database in the PostgreSQL instance created for the purpose.
- `TXLOG_PGHOST` (default: `172.17.0.1`): DNS or IP address of the host.
  The default value assumes that the PostgreSQL instance is running natively, i.e. outside of Docker.
- `TXLOG_PGPORT` (default: `5432`): Port of the PostgreSQL instance.
- `TXLOG_PGUSER` (default: `postgres`): Username of the PostgreSQL user used to log the transactions.
- `TXLOG_PGPASSWORD`: Password of the PostgreSQL user.

The variables may be passed to `docker-compose` or persisted in a `.env` file
(see [`testnet-txlog.env`](./testnet-txlog.env) and [`mainnet-txlog.env`](./mainnet-txlog.env)).
For example, run

```
export CONCORDIUM_NODE_TRANSACTION_OUTCOME_LOGGING=
export TXLOG_PGPASSWORD=<database-password>
```

before running the commands from the main documentation.

The reason behind the inconsistently named environment variables is explained in a comment in `docker-compose.yaml`.

## Disclaimer

Transaction logging should be enabled with care as it's a hard requirement that the database be available at all times:

- The node will crash in possibly unrecoverable ways if it cannot reach the database.
  Stop the node before doing backups of both node and DB data.
- No backfilling is performed, so transaction logging must be enabled from the initial catchup to be complete.

Writes only happen on block finalization so during normal operation the load is very low.

For the reasons above, this implementation of transaction logging is intended to be replaced by a more robust external solution in the near future.

## Setting up PostgreSQL

One way to deploy the database is to include it as an extra service in the Docker Compose file
(might be included under a specific profile in the future).

This is probably the easiest solution as the DB is then already on the same network as the Node.
It will also be directly "namespaced" to the project, avoiding interference between data from testnet and mainnet.

However, because of the strict availability requirements mentioned above, it may be preferable to run it separately,
either natively on the host or in another Docker (Compose) setup.

### Installing on Ubuntu host

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

### Installing in Kubernetes

Bitnami's Helm chart provides a very easy way of spinning up a PostgreSQL instance in Kubernetes:

1. Add the repo and install the chart:

   ```shell
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm install postgres-txlog --set postgresqlUsername=postgres,postgresqlPassword=<database-password>,postgresqlDatabase=<database-name> bitnami/postgresql
   ```

2. Forward port 5432 in order to connect to the DB with psql from outside the cluster:

   ```shell
   kubectl port-forward --namespace default svc/postgres-txlog-postgresql 5432:5432
   PGPASSWORD="<database-password>" psql --host 127.0.0.1 -U postgres -d <database-name> -p 5432
   ```