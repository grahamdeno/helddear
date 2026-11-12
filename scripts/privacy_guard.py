#!/usr/bin/env python3
"""Held Dear privacy guard. Run in CI.

Data stays on the phone: no network code, no analytics, no third-party SDKs.
Contacts are read only; the calendar is write only (one dinner event the user chose).
One exception, decided Nov 12, 2026: mailed cards. Only App/HeldDear/Services/MailedCards.swift may
make network requests, and only to Held Dear's own server at checkout.

  python3 -I scripts/privacy_guard.py check     scan App/ for forbidden calls
  python3 -I scripts/privacy_guard.py selftest  prove the scanner catches them
"""
import pathlib
import re
import sys

FORBIDDEN = {
    r"\bURLSession\b": "network request",
    r"\bURLRequest\b": "network request",
    r"\bLPMetadataProvider\b": "link preview fetch (network)",
    r"^\s*import\s+Network\b": "Network framework",
    r"\bNWConnection\b": "network connection",
    r"\bCNSaveRequest\b": "writing to Contacts",
    r"\brequestFullAccessToEvents\b": "reading the calendar",
    r"\bevents\(matching:": "reading calendar events",
    r"(?i)\b(firebase|amplitude|mixpanel|sentry|crashlytics|appsflyer)": "third-party SDK or analytics",
    r"requiresOnDeviceRecognition\s*=\s*false": "server-side speech recognition",
}


# The one file allowed to make network requests (mailed cards at checkout), and to which host.
NETWORK_ALLOWED = {"App/HeldDear/Services/MailedCards.swift"}
NETWORK_RULES = {"network request"}
ALLOWED_HOST = "helddear-mail.vercel.app"


def scan(text, name="<text>"):
    hits = []
    for i, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("///"):
            continue
        for pattern, why in FORBIDDEN.items():
            if name in NETWORK_ALLOWED and why in NETWORK_RULES:
                continue
            if re.search(pattern, line):
                hits.append(f"{name}:{i}: {why}: {stripped}")
        if name in NETWORK_ALLOWED:
            for host in re.findall(r"https?://([A-Za-z0-9.-]+)", line):
                if host != ALLOWED_HOST:
                    hits.append(f"{name}:{i}: network to a host other than {ALLOWED_HOST}: {stripped}")
    return hits


def check():
    root = pathlib.Path(__file__).resolve().parent.parent / "App"
    hits = []
    for path in sorted(root.rglob("*.swift")):
        hits += scan(path.read_text(encoding="utf-8"), str(path.relative_to(root.parent)))
    for h in hits:
        print(f"::error::{h}")
    if hits:
        sys.exit(1)
    print("Privacy guard: no network, analytics, contact writes or calendar reads found.")


def selftest():
    bad = ["let s = URLSession.shared", "import Network", "let r = CNSaveRequest()",
           "try await store.requestFullAccessToEvents()", "import FirebaseCore",
           "request.requiresOnDeviceRecognition = false"]
    for line in bad:
        assert scan(line), f"guard missed: {line}"
    assert not scan("// URLSession is never used here"), "comments should be ignored"
    assert not scan("request.requiresOnDeviceRecognition = true")
    allowed = "App/HeldDear/Services/MailedCards.swift"
    assert not scan("let (d, _) = try await URLSession.shared.data(for: r)", allowed), "mailed cards may use the network"
    assert not scan('static let baseURL = URL(string: "https://helddear-mail.vercel.app")!', allowed)
    assert scan('let u = URL(string: "https://example.com/track")', allowed), "only Held Dear\'s server is allowed"
    assert scan("let s = URLSession.shared", "App/HeldDear/Features/Home/HomeView.swift"), "other files stay offline"
    print("Privacy guard selftest passed.")


if __name__ == "__main__":
    {"check": check, "selftest": selftest}[sys.argv[1] if len(sys.argv) > 1 else "check"]()
