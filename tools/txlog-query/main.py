#!/usr/bin/env python

import os
import sys

from query import *
from representations import *


def address_to_bytes(a):
    # Attempt to parse as Base58Check, falling back to hex (with optional prefix).
    try:
        return bytes_from_base58check(a)
    except:
        return bytes.fromhex(a[a.find('x') + 1:])  # strip any prefix ending with 'x'


if __name__ == '__main__':
    host = os.getenv('PGHOST', 'localhost')
    port = int(os.getenv('PGPORT', '5432'))
    database = os.getenv('PGDATABASE', 'concordium_txlog')
    user = os.getenv('PGUSER', 'postgres')
    password = os.getenv('PGPASSWORD')
    account_address_bytes = address_to_bytes(sys.argv[1])

    print("Address (Base58Check):", base58check_from_bytes(account_address_bytes))
    print("Address (Hex)        :", account_address_bytes.hex())

    connection = connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password,
    )

    rows = query_by_address_bytes(connection, account_address_bytes)
    for address, block, timestamp, height, summary_json in rows:
        assert address.tobytes() == account_address_bytes
        print(summary_json)
