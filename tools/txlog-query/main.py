#!/usr/bin/env python

from translate_address import *
from query import *
import sys, os

if __name__ == '__main__':
    host = os.getenv('PGHOST', 'localhost')
    port = int(os.getenv('PGPORT', '5432'))
    database = os.getenv('PGDATABASE', 'concordium_txlog')
    user = os.getenv('PGUSER', 'postgres')
    password = os.getenv('PGPASSWORD')
    account_address = sys.argv[1]

    connection = connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password,
    )

    rows = query_by_address_bytes(connection, bytes_from_base58check(account_address))
    for (address, block, timestamp, height, summary) in rows:
        # Round-trip sanity check.
        assert (base58check_from_bytes(address) == account_address)
        print(summary)
