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
    contract_index = address_to_bytes(sys.argv[1])  # '29' has lots of transactions...
    #
    # print("Address (Base58Check):", account_address.base58check())
    # print("Address (Hex)        :", account_address.hex())

    connection = connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password,
    )

    block_hashes = query_blocks_affecting_contract_by_index(connection, contract_index)
    print(block_hashes)

    # TODO Query state/view function of contract for all returned blocks (note that the hashes have type 'memoryview').
