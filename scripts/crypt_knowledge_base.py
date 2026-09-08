#!/usr/bin/env python3

"""crypt_knowledge_base.py

A simple filter script for Git clean/smudge that encrypts/decrypts
`core_knowledge_base.md` using AES‑256‑GCM.

Usage:
  python crypt_knowledge_base.py --mode clean   # encrypt (Git clean)
  python crypt_knowledge_base.py --mode smudge  # decrypt (Git smudge)

The script reads the file from stdin and writes the result to stdout.
The encryption key is taken from the environment variable `KB_ENCRYPTION_KEY`
( Base64‑encoded 32‑byte key ).
"""

import os, sys, argparse, base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def load_key():
    key_b64 = os.getenv('KB_ENCRYPTION_KEY')
    if not key_b64:
        sys.stderr.write('Error: KB_ENCRYPTION_KEY env var not set\n')
        sys.exit(1)
    try:
        key = base64.b64decode(key_b64)
    except Exception as e:
        sys.stderr.write('Error decoding KB_ENCRYPTION_KEY: %s\n' % e)
        sys.exit(1)
    if len(key) != 32:
        sys.stderr.write('Error: KB_ENCRYPTION_KEY must be 32 bytes (AES‑256) after base64 decoding\n')
        sys.exit(1)
    return key

def encrypt(data, key):
    # AES‑GCM requires a 12‑byte nonce
    nonce = os.urandom(12)
    aesgcm = AESGCM(key)
    ct = aesgcm.encrypt(nonce, data, None)
    # Store nonce + ciphertext, base64‑encode for safe transport
    return base64.b64encode(nonce + ct)

def decrypt(data_b64, key):
    try:
        data = base64.b64decode(data_b64)
    except Exception as e:
        sys.stderr.write('Error decoding encrypted data: %s\n' % e)
        sys.exit(1)
    nonce = data[:12]
    ct = data[12:]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ct, None)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', choices=['clean', 'smudge'], required=True)
    args = parser.parse_args()
    key = load_key()
    raw = sys.stdin.buffer.read()
    if args.mode == 'clean':
        out = encrypt(raw, key)
    else:
        out = decrypt(raw, key)
    sys.stdout.buffer.write(out)

if __name__ == '__main__':
    main()
