#!/usr/bin/env python

from json import loads
from query import *
from jsondiff import diff
import sys


if __name__ == '__main__':
    block_height = sys.argv[1]
    block_hash1 = sys.argv[2]
    block_hash2 = sys.argv[3]

    connection1 = connect(
        host='localhost',
        database='testnet_concordium_txlog',
        port=5432,
        user='postgres',
        password='1234',
    )
    connection2 = connect(
        host='localhost',
        database='testnet_concordium_txlog_service',
        port=5432,
        user='postgres',
        password='1234',
    )

    row1 = query_by_block_height_and_hash(connection1, block_height, block_hash1)[0]
    row2 = query_by_block_height_and_hash(connection2, block_height, block_hash2)[0]

    res1 = loads(row1[4])
    res2 = loads(row2[4])
    #print(row1[4])
    #print(row2[4])

    if res1 == res2:
        print('Parsed results match!')
    else:
        print('Parsed results differ:')
        diff_res = diff(res1, res2)
        print(diff_res)
