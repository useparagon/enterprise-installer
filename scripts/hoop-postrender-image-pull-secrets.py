#!/usr/bin/env python3
"""Helm postrender: attach a docker pull secret to hoopagent (chart has no imagePullSecrets)."""

from __future__ import annotations

import sys


def patch(manifest: str, secret_name: str) -> str:
    docs = manifest.split("\n---\n")
    patched = []
    for doc in docs:
        if "kind: Deployment" in doc and "name: hoopagent" in doc and "imagePullSecrets:" not in doc:
            if "      serviceAccountName: hoopagent\n" in doc:
                doc = doc.replace(
                    "      serviceAccountName: hoopagent\n",
                    "      serviceAccountName: hoopagent\n"
                    f"      imagePullSecrets:\n        - name: {secret_name}\n",
                    1,
                )
            elif "    spec:\n      containers:\n" in doc:
                doc = doc.replace(
                    "    spec:\n      containers:\n",
                    "    spec:\n"
                    f"      imagePullSecrets:\n        - name: {secret_name}\n"
                    "      containers:\n",
                    1,
                )
        if "kind: ServiceAccount" in doc and "name: hoopagent" in doc and "imagePullSecrets:" not in doc:
            doc = doc.rstrip() + f"\nimagePullSecrets:\n  - name: {secret_name}\n"
        patched.append(doc)
    return "\n---\n".join(patched)


def main() -> int:
    if len(sys.argv) < 2 or not sys.argv[1]:
        sys.stderr.write("usage: hoop-postrender-image-pull-secrets.py <secret-name>\n")
        return 1
    sys.stdout.write(patch(sys.stdin.read(), sys.argv[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
