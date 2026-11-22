#!/usr/bin/env python3
"""Held Dear privacy guard. Run in CI.

Data stays on the phone: no network code, no analytics, no third-party SDKs.
Contacts are read only; the calendar is write only (one dinner event the user chose).
Two exceptions, both decided Nov 12, 2026, both only to Held Dear's own server:
mailed cards (App/HeldDear/Services/MailedCards.swift, at checkout) and family pages
(App/HeldDear/Services/FamilyPages.swift, when the user makes or manages a page).

  python3 -I scripts/privacy_guard.py check     scan App/ for forbidden calls
  python3 -I scripts/privacy_guard.py selftest  prove the scanner catches them
"""
import hashlib
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


# The only files allowed to make network requests, and to which host.
NETWORK_ALLOWED = {"App/HeldDear/Services/MailedCards.swift", "App/HeldDear/Services/FamilyPages.swift"}
# Link previews (Graham, Nov 21, 2026): only this file may ask a saved idea's own page for its title and image,
# with Apple's LinkPresentation. No other network call is allowed in it.
PREVIEW_ALLOWED = {"App/HeldDear/Services/LinkPreviews.swift"}
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
            if name in PREVIEW_ALLOWED and why == "link preview fetch (network)":
                continue
            if re.search(pattern, line):
                hits.append(f"{name}:{i}: {why}: {stripped}")
        if name in NETWORK_ALLOWED:
            for host in re.findall(r"https?://([A-Za-z0-9.-]+)", line):
                if host != ALLOWED_HOST:
                    hits.append(f"{name}:{i}: network to a host other than {ALLOWED_HOST}: {stripped}")
    return hits


# Real family names never go in the code (Fable P1, Nov 21, 2026). Kept as short hashes so this list doesn't
# publish the names it protects. A word matches when the first 16 hex digits of sha256(lowercased word) are here.
NAME_HASHES = {'d3b4e2f584367e52', '5fd235b1f1e86c32', 'efa9751a2cb99f51', '77c669164c377e39', '05a331a7f4f1929f', 'd277670919a94ba3', 'b93f52c7073cb35b', 'b21ec07effd3fe30', 'b78469618fb15871', 'db9763c0e62cb499'}
NAME_SCAN_ROOTS = ["App", "server/lib", "server/api", "server/test", "scripts"]


def name_hits(text, name="<text>"):
    hits = []
    for i, line in enumerate(text.splitlines(), 1):
        for word in re.findall(r"[A-Za-z]+", line):
            if hashlib.sha256(word.lower().encode()).hexdigest()[:16] in NAME_HASHES:
                hits.append(f"{name}:{i}: a real family name; use an invented one")
                break
    return hits


def check():
    root = pathlib.Path(__file__).resolve().parent.parent / "App"
    hits = []
    for path in sorted(root.rglob("*.swift")):
        hits += scan(path.read_text(encoding="utf-8"), str(path.relative_to(root.parent)))
    repo = root.parent
    for sub in NAME_SCAN_ROOTS:
        for path in sorted((repo / sub).rglob("*")):
            if path.is_file() and path.suffix in {".swift", ".js", ".py", ".json", ".strings"}:
                hits += name_hits(path.read_text(encoding="utf-8", errors="ignore"), str(path.relative_to(repo)))
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
    preview = "App/HeldDear/Services/LinkPreviews.swift"
    assert not scan("let provider = LPMetadataProvider()", preview), "link previews may fetch a saved page"
    assert scan("let s = URLSession.shared", preview), "link previews may not make other requests"
    assert scan("let provider = LPMetadataProvider()", "App/HeldDear/Features/Plan/PlanView.swift"), "only LinkPreviews fetches previews"
    assert name_hits('XCTAssertEqual(NameSize.page("' + "Hei" + 'di"), 96)'), "real names are caught"
    assert not name_hits('XCTAssertEqual(NameSize.page("Ada"), 96)'), "invented names pass"
    print("Privacy guard selftest passed.")


if __name__ == "__main__":
    {"check": check, "selftest": selftest}[sys.argv[1] if len(sys.argv) > 1 else "check"]()
