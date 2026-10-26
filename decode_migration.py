#!/usr/bin/env python3
"""Decode an otpauth-migration:// link (Google Authenticator export)
and print the base32 secret key for each account.

Usage:
    python3 decode_migration.py 'otpauth-migration://offline?data=...'

Uses only the standard library. Everything is processed locally.
"""
import sys
import base64
import urllib.parse as up


def varint(b, i):
    """Read a protobuf varint from bytes b starting at index i."""
    n = s = 0
    while True:
        c = b[i]
        i += 1
        n |= (c & 0x7F) << s
        s += 7
        if not c & 0x80:
            return n, i


def fields(b):
    """Yield (field_number, value) pairs from a protobuf message."""
    i = 0
    while i < len(b):
        k, i = varint(b, i)
        f, w = k >> 3, k & 7
        if w == 0:
            v, i = varint(b, i)
        elif w == 2:
            l, i = varint(b, i)
            v = b[i:i + l]
            i += l
        else:
            raise ValueError("unexpected format")
        yield f, v


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    url = sys.argv[1].replace("QR-Code:", "", 1)
    data = up.parse_qs(up.urlparse(url).query)["data"][0].replace(" ", "+")
    raw = base64.b64decode(data + "=" * (-len(data) % 4))

    # Field 1 holds one entry per exported account
    for f, v in fields(raw):
        if f != 1:
            continue
        name = issuer = secret = ""
        for g, w in fields(v):
            if g == 1:
                # Raw secret bytes -> base32, which is what oathtool -b expects
                secret = base64.b32encode(w).decode().rstrip("=")
            elif g == 2:
                name = w.decode()
            elif g == 3:
                issuer = w.decode()
        print(f"{issuer} / {name}\n  {secret}\n")


if __name__ == "__main__":
    main()
