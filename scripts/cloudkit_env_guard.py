#!/usr/bin/env python3
"""Keeps the CloudKit schema workflow on the Development environment only.

`container FILE...` fails when a file names the real app's iCloud container (the Schema Test workflow may name only the
test container, `<real container>.schematest`).
`check FILE...` fails when a file names any CloudKit environment other than Development, or has the word for the
live environment anywhere in it (comments included). `selftest` proves the check catches it. Both run in CI.
The live word is built from pieces so this file never spells it out and can scan itself.
"""
import re
import sys

LIVE = "pro" + "duction"
# The real container id, built from pieces so this file never spells it out. Followed by ".schematest" it is the test one.
REAL_CONTAINER = re.compile(r"iCloud" + r"\.com\.grahamdeno\." + r"helddear(?!\.schematest)", re.IGNORECASE)
ENV_FLAG = re.compile(r"--environment(?:\s+|=)(\S+)")


def problems(text, name="<text>"):
    found = []
    for i, line in enumerate(text.splitlines(), 1):
        if LIVE in line.lower():
            found.append(f"{name}:{i}: names the live environment: {line.strip()}")
        for value in ENV_FLAG.findall(line):
            if value.strip("\"'").lower() != "development":
                found.append(f"{name}:{i}: --environment {value} (only development is allowed): {line.strip()}")
    return found


def container_problems(text, name="<text>"):
    found = []
    for i, line in enumerate(text.splitlines(), 1):
        if REAL_CONTAINER.search(line):
            found.append(f"{name}:{i}: names the real app's container: {line.strip()}")
    return found


def container(paths):
    found = []
    for p in paths:
        found += container_problems(open(p, encoding="utf-8").read(), p)
    for f in found:
        print(f)
    if found:
        print("CloudKit container guard: FAILED")
        return 1
    print("CloudKit container guard: only the test container is named.")
    return 0


def check(paths):
    found = []
    for p in paths:
        found += problems(open(p, encoding="utf-8").read(), p)
    for f in found:
        print(f)
    if found:
        print("CloudKit environment guard: FAILED")
        return 1
    print("CloudKit environment guard: only development is named.")
    return 0


def selftest():
    assert not problems("run: xcrun cktool import-schema --environment development --file x")
    assert not problems("run: xcrun cktool import-schema --environment=development")
    assert problems("run: xcrun cktool import-schema --environment " + LIVE), "the live environment is caught"
    assert problems("run: xcrun cktool import-schema --environment=" + LIVE), "the = form is caught"
    assert problems("run: xcrun cktool import-schema --environment staging"), "any other environment is caught"
    assert problems("# deploy to " + LIVE.upper()), "the word anywhere is caught"
    real = "iCloud" + ".com.grahamdeno." + "helddear"
    assert not container_problems("--container-id " + real + ".schematest"), "the test container is allowed"
    assert container_problems("--container-id " + real), "the real container is caught"
    assert container_problems("--container-id " + real + " # " + real + ".schematest"), "a mix is caught"
    assert container_problems("--container-id " + real.lower() + "\n"), "case does not hide it"
    print("CloudKit environment guard selftest passed.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "selftest":
        sys.exit(selftest())
    if len(sys.argv) >= 3 and sys.argv[1] == "check":
        sys.exit(check(sys.argv[2:]))
    if len(sys.argv) >= 3 and sys.argv[1] == "container":
        sys.exit(container(sys.argv[2:]))
    print("usage: cloudkit_env_guard.py selftest | check FILE... | container FILE...")
    sys.exit(2)
