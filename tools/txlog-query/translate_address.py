import base58


def hex_from_base58check(input):
    return bytes_from_base58check(input).hex()


def bytes_from_base58check(input):
    # The first byte in the Base58Check encoding is the version
    # which is not included in the hex representation.
    return base58.b58decode_check(input)[1:]


def base58check_from_hex(input):
    return base58check_from_bytes(bytes.fromhex(input))


def base58check_from_bytes(input):
    # The first byte in the Base58Check encoding is the version
    # which is not included in the hex representation.
    return base58.b58encode_check(bytes(b'\x01') + input).decode()
