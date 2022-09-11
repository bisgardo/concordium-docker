import encoding

base58check_version = 1


class Address:
    def __init__(self, bytes):
        self.bytes = bytes

    def base58check(self):
        return encoding.base58check_from_bytes(base58check_version, self.bytes)

    def hex(self):
        return encoding.hex_from_bytes(self.bytes)


def address_from_base58check(input):
    v, bs = encoding.bytes_from_base58check(input)
    if v != base58check_version:
        raise Exception(f"unexpected version byte '{v}'")
    return Address(bs)


def address_from_hex(input):
    bs = encoding.bytes_from_hex(input)
    return Address(bs)
