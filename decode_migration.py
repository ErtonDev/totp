#!/usr/bin/env python3
"""Decodifica un enlace otpauth-migration:// (export de Google Authenticator)
y muestra, para cada cuenta, la clave secreta en base32.

Uso:
    python3 decode_migration.py 'otpauth-migration://offline?data=...'

Solo usa la librería estándar. Todo se procesa en local.
"""
import sys
import base64
import urllib.parse as up


def varint(b, i):
    n = s = 0
    while True:
        c = b[i]
        i += 1
        n |= (c & 0x7F) << s
        s += 7
        if not c & 0x80:
            return n, i


def fields(b):
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
            raise ValueError("formato inesperado")
        yield f, v


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    url = sys.argv[1].replace("QR-Code:", "", 1)
    data = up.parse_qs(up.urlparse(url).query)["data"][0].replace(" ", "+")
    raw = base64.b64decode(data + "=" * (-len(data) % 4))

    for f, v in fields(raw):
        if f != 1:
            continue
        name = issuer = secret = ""
        for g, w in fields(v):
            if g == 1:
                secret = base64.b32encode(w).decode().rstrip("=")
            elif g == 2:
                name = w.decode()
            elif g == 3:
                issuer = w.decode()
        print(f"{issuer} / {name}\n  {secret}\n")


if __name__ == "__main__":
    main()
