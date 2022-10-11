#!/usr/bin/env python

import base58, io

h = "0100204c87702e59844fd19a6799b750b8391ddea4cb23f6436902d7c017133e01959d010000000000000000201c6a8a937ccbf073714e596c92f5d37598a79176d6dfe6a49f3cc7f38710e401a61b00000000000000000000000000001900426963746f72794e667441756374696f6e2e61756374696f6e24000183d03d89830100000000840c240000000000d3fb2f010000000040420f000000000000"


def transfer_parameter(bs):
    n = int.from_bytes(bs.read(2), byteorder='little')
    return transfers(bs, n)


def transfers(bs, n):
    return [transfer(bs) for _ in range(n)]


def transfer(bs):
    id_ = token_id(bs)
    amount = token_amount(bs)
    from_ = address(bs)
    to = receiver(bs)
    data = additional_data(bs)
    return [id_, amount, from_, to, data]


def token_id(bs):
    n = int.from_bytes(bs.read(1), byteorder='little')
    return int.from_bytes(bs.read(n), byteorder='little')


def token_amount(bs):
    return int.from_bytes(bs.read(8), byteorder='little')


def address(bs):
    t = int.from_bytes(bs.read(1), byteorder='little')
    if t == 0:
        return account_address(bs)
    elif t == 1:
        return contract_address(bs)
    else:
        raise Exception('invalid type')


def account_address(bs):
    addr = bs.read(32)
    return base58.b58encode_check(b'\x01' + addr).decode()


def contract_address(bs):
    return int.from_bytes(bs.read(8), byteorder='little'), int.from_bytes(bs.read(8), byteorder='little')


def receiver(bs):
    t = int.from_bytes(bs.read(1), byteorder='little')
    if t == 0:
        return account_address(bs)
    elif t == 1:
        return contract_address(bs), receive_hook_name(bs)
    else:
        raise Exception('invalid type')


def receive_hook_name(bs):
    n = int.from_bytes(bs.read(2), byteorder='little')
    name = bs.read(n)
    return bytes.decode(name, 'ascii')


def additional_data(bs):
    n = int.from_bytes(bs.read(2), byteorder='little')
    data = bs.read(n)
    return data


print(transfer_parameter(io.BytesIO(bytes.fromhex(h))))
