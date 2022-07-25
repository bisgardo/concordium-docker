import base58


def bytes_from_base58check(input):
    # The first byte in the Base58Check encoding is the version.
    bs = base58.b58decode_check(input)
    return bs[0], bs[1:]


def base58check_from_bytes(version_byte, input):
    return base58.b58encode_check(bytes([version_byte]) + input).decode()


def hex_from_bytes(input):
    return input.hex()


def bytes_from_hex(input):
    return bytes.fromhex(input)
