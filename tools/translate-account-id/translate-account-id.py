#!/usr/bin/env python

# Script for translating account IDs between the common address representation (base58-check)
# and the hex representation used in (at least) the PostgreSQL database for transaction logging.

import base58, sys

# Start by assuming that the input is a base58-check encoded account and fall back to hex if decoding fails.
input = sys.argv[1]
try:
    hex = base58.b58decode_check(input)[1:].hex()  # the first byte is the version which is not included in the hex representation
    print("Base58-check: " + input)
    print("Hex:          " + hex)
except:
    base58check = base58.b58encode_check(bytes(b'\x01') + bytes.fromhex(input)).decode()
    print("Base58-check: " + base58check)
    print("Hex:          " + input)
