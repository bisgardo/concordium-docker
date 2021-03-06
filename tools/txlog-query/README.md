# `txlog-query`

Simple Python tool for querying the PostgreSQL database used for transaction logging.
It accepts the connection values for the database and an account address in Base58Check format.
The necessary format conversions are performed internally and the complete list of summaries for the account is printed out as JSON.

While the tool may be somewhat useful on its own, its real purpose is to serve as a starting place for more complex applications.

## Usage

*Build:*

```shell
docker build -t txlog-query --pull .
```

*Run:*

```shell
docker run -e PGHOST=<db-host> -e PGPORT=<db-port> -e PGDATABASE=<db-name> -e PGUSER=<db-user> -e PGPASSWORD=<db-password> txlog-query <address>
```

where
- `<db-host>` is the network address of the host running the PostgreSQL instance (default: `localhost`).
  When tool is running in Docker but PostgreSQL isn't, this should likely be changed to `172.17.0.1`.
- `<db-port>` is the host port that PostgreSQL is running on (default: `5432`).
- `<db-name>` is the database on the PostgreSQL instance (default: `concordium_txlog`).
- `<db-user>` is the PostgreSQL user used to query the database (default: `postgres`).
- `<db-password>` is the password for `<db-user>`.
- `<address>` is an account address represented in either Base58Check format or hex (ignoring any prefix ending with `x`).
