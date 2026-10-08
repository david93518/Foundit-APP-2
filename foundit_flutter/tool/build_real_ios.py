"""Run on the Mac: validate real-beta configuration, then build a signed IPA.

No private keys or passwords are accepted by this script. Google client IDs
are public application identifiers. Xcode signing must already be configured.
"""
import argparse
import ipaddress
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
CLIENT_ID = re.compile(r"[0-9]+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com\Z")


def validate(args):
    for name in ("ios_client_id", "web_client_id"):
        if not CLIENT_ID.fullmatch(getattr(args, name)):
            raise ValueError(f"{name}: supply the Google OAuth client ID")
    if args.ios_client_id == args.web_client_id:
        raise ValueError("iOS and Web require separate OAuth client IDs")
    url = urlparse(args.origin)
    if (url.scheme != "https" or not url.hostname or url.username or url.password
            or url.path not in ("", "/") or url.query or url.fragment):
        raise ValueError("origin must be an HTTPS origin without a path or credentials")
    host = url.hostname.lower()
    if "." not in host or host.endswith((".local", ".localhost", ".internal")):
        raise ValueError("origin must use a public hostname")
    try:
        ipaddress.ip_address(host)
    except ValueError:
        pass
    else:
        raise ValueError("origin must use a DNS hostname, not an IP address")
    if args.build_number < 2:
        raise ValueError("build number must be at least 2; build 1 is the old mock build")
    return args.origin.rstrip("/")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ios-client-id", required=True)
    parser.add_argument("--web-client-id", required=True)
    parser.add_argument("--origin", required=True)
    parser.add_argument("--build-number", required=True, type=int)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--configure-only", action="store_true")
    args = parser.parse_args()
    try:
        origin = validate(args)
    except ValueError as error:
        parser.error(str(error))
    # One input generates both native callback settings and Dart IDs, avoiding
    # a native/Dart mismatch. These generated files are not committed.
    native = ROOT / "ios/Flutter/GoogleSignIn.xcconfig"
    native.write_text(
        f"GOOGLE_IOS_CLIENT_ID = {args.ios_client_id}\n"
        f"GOOGLE_WEB_CLIENT_ID = {args.web_client_id}\n"
        f"GOOGLE_REVERSED_CLIENT_ID = {'.'.join(reversed(args.ios_client_id.split('.')))}\n",
        encoding="utf-8",
    )
    config = ROOT / "build/real-ios-defines.json"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps({
        "USE_MOCK": False, "PROD": True,
        "API_BASE_URL": origin + "/api/v1", "SOCKET_HOST": origin,
        "GOOGLE_IOS_CLIENT_ID": args.ios_client_id,
        "GOOGLE_WEB_CLIENT_ID": args.web_client_id,
    }, indent=2), encoding="utf-8")
    print("Native callback and real API build configuration generated.")
    print("This does not verify DNS, HTTPS reachability, OAuth ownership or real login.")
    if not args.configure_only:
        subprocess.run([
            args.flutter, "build", "ipa", "--release",
            f"--build-number={args.build_number}",
            f"--dart-define-from-file={config}",
        ], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
