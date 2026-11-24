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
# The one Contacts write (Graham, Nov 22, 2026): a birthday added to a card that has none, on the user's tap.
CONTACT_WRITE_ALLOWED = {"App/HeldDear/Services/ContactWriteBack.swift"}
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
            if name in CONTACT_WRITE_ALLOWED and why == "writing to Contacts":
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


# The Schema Test app (Nov 23, 2026) shares the app sources but its own code never reaches the real app: the compile flag
# SCHEMA_TEST may appear only in these Swift files (and in tests, which only read it as text), its folder is not a source of the real target, and the real
# target never sets the flag.
SCHEMA_TEST_FILES = {"App/HeldDear/App/HeldDearApp.swift", "App/HeldDear/App/CloudKitSeed.swift"}
SCHEMA_TEST_DIR = "App/HeldDearSchemaTest/"


def schema_test_hits(swift_files, project_yml):
    """swift_files: {relative path: text}. project_yml: the text of project.yml."""
    hits = []
    for name, text in swift_files.items():
        if "SCHEMA_TEST" in text and name not in SCHEMA_TEST_FILES and not name.startswith(SCHEMA_TEST_DIR) \
                and not name.startswith("App/HeldDearTests/"):
            hits.append(f"{name}: SCHEMA_TEST outside the files that may use it")
        if name.startswith(SCHEMA_TEST_DIR):
            stripped = text.strip()
            if not stripped.startswith("#if SCHEMA_TEST") or not stripped.endswith("#endif"):
                hits.append(f"{name}: a Schema Test file must sit entirely inside #if SCHEMA_TEST")
    start = project_yml.find("\n  HeldDear:\n")
    end = project_yml.find("\n  HeldDearSchemaTest:\n")
    if start < 0 or end < start:
        hits.append("project.yml: could not find the HeldDear target block before the HeldDearSchemaTest block")
    else:
        real = project_yml[start:end]
        if "SCHEMA_TEST" in real or "HeldDearSchemaTest" in real:
            hits.append("project.yml: the real HeldDear target must not mention SCHEMA_TEST or the Schema Test folder")
    return hits


SERVER_FLAGS = ("HELDDEAR_MAILED_CARDS", "HELDDEAR_FAMILY_PAGES")


def server_flag_hits(files):
    """1.0 is server-free (Graham, Nov 24, 2026, plan B): no build setting or workflow may turn on mailed cards or
    family pages. `files` maps a path to its text (project.yml and the workflows)."""
    hits = []
    for name, text in files.items():
        for i, line in enumerate(text.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            for flag in SERVER_FLAGS:
                if flag in stripped:
                    hits.append(f"{name}:{i}: 1.0 must not turn on {flag} (server features are off until 1.1): {stripped}")
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
    swift_files = {str(p.relative_to(repo)): p.read_text(encoding="utf-8") for p in sorted(root.rglob("*.swift"))}
    hits += schema_test_hits(swift_files, (repo / "project.yml").read_text(encoding="utf-8"))
    build_files = {"project.yml": (repo / "project.yml").read_text(encoding="utf-8")}
    for wf in sorted((repo / ".github" / "workflows").glob("*.yml")):
        build_files[str(wf.relative_to(repo))] = wf.read_text(encoding="utf-8")
    hits += server_flag_hits(build_files)
    for h in hits:
        print(f"::error::{h}")
    if hits:
        sys.exit(1)
    print("Privacy guard: no network, analytics, contact writes (beyond ContactWriteBack) or calendar reads found.")


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
    writer = "App/HeldDear/Services/ContactWriteBack.swift"
    assert not scan("let request = CNSaveRequest()", writer), "the write-back file may add a birthday"
    assert scan("let s = URLSession.shared", writer), "the write-back file stays offline"
    assert scan("let r = CNSaveRequest()", "App/HeldDear/Features/Person/PersonView.swift"), "only ContactWriteBack writes"
    assert name_hits('XCTAssertEqual(NameSize.page("' + "Hei" + 'di"), 96)'), "real names are caught"
    assert not name_hits('XCTAssertEqual(NameSize.page("Ada"), 96)'), "invented names pass"
    yml_ok = "\n  HeldDear:\n    settings: x\n  HeldDearSchemaTest:\n    flags: SCHEMA_TEST\n  HeldDearShare:\n    x: y\nschemes:\n"
    assert not schema_test_hits({"App/HeldDear/App/HeldDearApp.swift": "#if SCHEMA_TEST\n#endif",
                                 "App/HeldDearSchemaTest/A.swift": "#if SCHEMA_TEST\nlet a = 1\n#endif\n"}, yml_ok)
    assert schema_test_hits({"App/HeldDear/Features/Home/HomeView.swift": "#if SCHEMA_TEST\n#endif"}, yml_ok), "the flag stays in its files"
    assert not schema_test_hits({"App/HeldDearTests/X.swift": 'XCTAssertFalse(real.contains("SCHEMA_TEST"))'}, yml_ok), "tests may read the word"
    assert schema_test_hits({"App/HeldDearSchemaTest/A.swift": "let a = 1\n"}, yml_ok), "a Schema Test file must be wrapped"
    assert schema_test_hits({}, yml_ok.replace("settings: x", "flags: SCHEMA_TEST")), "the real target may not set the flag"
    assert schema_test_hits({}, yml_ok.replace("settings: x", "sources: App/HeldDearSchemaTest")), "the real target may not list the folder"
    assert server_flag_hits({"project.yml": "SWIFT_ACTIVE_COMPILATION_CONDITIONS: HELDDEAR_MAILED_CARDS"}), "1.0 stays server-free"
    assert server_flag_hits({"t.yml": "x='$(inherited) HELDDEAR_FAMILY_PAGES'"}), "family pages stay off"
    assert not server_flag_hits({"t.yml": "# HELDDEAR_MAILED_CARDS comes back in 1.1"}), "comments may name the flag"
    assert not server_flag_hits({"t.yml": "x='$(inherited) HELDDEAR_TESTFLIGHT_TOOLS'"}), "other flags are fine"
    print("Privacy guard selftest passed.")


if __name__ == "__main__":
    {"check": check, "selftest": selftest}[sys.argv[1] if len(sys.argv) > 1 else "check"]()
