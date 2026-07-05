#!/usr/bin/env python3
import os, base64, argparse
from cryptography.hazmat.primitives.asymmetric import ed25519

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="./keys")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    priv = ed25519.Ed25519PrivateKey.generate()
    pub = priv.public_key()

    priv_path = os.path.join(args.out, "decision_private.key")
    pub_path  = os.path.join(args.out, "decision_public.key.b64")

    with open(priv_path, "wb") as f:
        f.write(priv.private_bytes_raw())

    pub_b = pub.public_bytes_raw()
    with open(pub_path, "w", encoding="utf-8") as f:
        f.write(base64.b64encode(pub_b).decode("ascii"))

    print("[keygen] wrote:")
    print(" ", priv_path)
    print(" ", pub_path)

if __name__ == "__main__":
    main()
