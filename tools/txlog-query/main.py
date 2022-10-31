#!/usr/bin/env python

import os
import sys

from query import *
from address import *


def address_to_bytes(a):
    # Attempt to parse as Base58Check, falling back to hex (with optional prefix).
    try:
        return address_from_base58check(a)
    except:
        hex = a[a.find('x') + 1:]  # strip any prefix ending with 'x'
        return address_from_hex(hex)


if __name__ == '__main__':
    host = os.getenv('PGHOST', 'localhost')
    port = int(os.getenv('PGPORT', '5432'))
    database = os.getenv('PGDATABASE', 'concordium_txlog')
    user = os.getenv('PGUSER', 'postgres')
    password = os.getenv('PGPASSWORD')
    account_address = address_to_bytes(sys.argv[1])

    print("Address (Base58Check):", account_address.base58check())
    print("Address (Hex)        :", account_address.hex())

    connection = connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password,
    )

    rows = query_by_address_bytes(connection, account_address.bytes)
    for address, block, timestamp, height, summary_json in rows:
        assert address.tobytes() == account_address.bytes
        print(summary_json)
