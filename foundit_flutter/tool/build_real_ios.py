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
FIREBASE_API_KEY = re.compile(r"AIza[0-9A-Za-z_-]{35}\Z")
FIREBASE_IOS_APP_ID = re.compile(r"[0-9]+:[0-9]+:ios:[0-9a-f]+\Z")
# Must match ios/Runner/*.entitlements and the backend's apple-app-site-association.
LINK_HOST = "api.foundit.tw"


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
    firebase = (args.firebase_ios_api_key, args.firebase_ios_app_id)
    if any(firebase) and not all(firebase):
        raise ValueError("push needs both --firebase-ios-api-key and --firebase-ios-app-id")
    if args.firebase_ios_api_key and not FIREBASE_API_KEY.fullmatch(args.firebase_ios_api_key):
        raise ValueError("--firebase-ios-api-key: copy API_KEY from GoogleService-Info.plist")
    if args.firebase_ios_app_id and not FIREBASE_IOS_APP_ID.fullmatch(args.firebase_ios_app_id):
        raise ValueError("--firebase-ios-app-id: copy GOOGLE_APP_ID from GoogleService-Info.plist")
    if args.build_number < 2:
        raise ValueError("build number must be at least 2; build 1 is the old mock build")
    return args.origin.rstrip("/")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ios-client-id", required=True)
    parser.add_argument("--web-client-id", required=True)
    parser.add_argument("--origin", required=True)
    parser.add_argument("--build-number", required=True, type=int)
    # Firebase iOS app config (public identifiers from GoogleService-Info.plist).
    # Omit both to build without push; the app then keeps chat in-app only.
    parser.add_argument("--firebase-ios-api-key", default="")
    parser.add_argument("--firebase-ios-app-id", default="")
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--configure-only", action="store_true")
    args = parser.parse_args()
    try:
        origin = validate(args)
    except ValueError as error:
        parser.error(str(error))
    push = bool(args.firebase_ios_app_id)
    # One input generates both native callback settings and Dart IDs, avoiding
    # a native/Dart mismatch. These generated files are not committed.
    native = ROOT / "ios/Flutter/GoogleSignIn.xcconfig"
    native.write_text(
        f"GOOGLE_IOS_CLIENT_ID = {args.ios_client_id}\n"
        f"GOOGLE_WEB_CLIENT_ID = {args.web_client_id}\n"
        f"GOOGLE_REVERSED_CLIENT_ID = {'.'.join(reversed(args.ios_client_id.split('.')))}\n"
        # The push entitlement is only signed in when push is configured, so a
        # build without Firebase never needs the Push capability on the App ID.
        # Both files carry the Universal Links domain (Associated Domains capability).
        + f"CODE_SIGN_ENTITLEMENTS = Runner/{'Runner' if push else 'RunnerLinks'}.entitlements\n",
        encoding="utf-8",
    )
    config = ROOT / "build/real-ios-defines.json"
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps({
        "USE_MOCK": False, "PROD": True,
        "API_BASE_URL": origin + "/api/v1", "SOCKET_HOST": origin,
        "GOOGLE_IOS_CLIENT_ID": args.ios_client_id,
        "GOOGLE_WEB_CLIENT_ID": args.web_client_id,
        **({
            "FIREBASE_IOS_API_KEY": args.firebase_ios_api_key,
            "FIREBASE_IOS_APP_ID": args.firebase_ios_app_id,
        } if push else {}),
    }, indent=2), encoding="utf-8")
    print("Native callback and real API build configuration generated.")
    print("Push notifications: " + ("enabled (Firebase iOS app + push entitlement)." if push
          else "DISABLED - pass --firebase-ios-api-key and --firebase-ios-app-id to enable."))
    if urlparse(origin).hostname != LINK_HOST:
        print(f"WARNING: entitlements declare applinks:{LINK_HOST}; "
              "QR stickers on another host will open Safari, not the app.")
    print("This does not verify DNS, HTTPS reachability, OAuth ownership or real login.")
    if not args.configure_only:
        subprocess.run([
            args.flutter, "build", "ipa", "--release",
            # Dart symbols are obfuscated; keep build/debug-info to symbolicate crash stacks.
            "--obfuscate", "--split-debug-info=build/debug-info",
            f"--build-number={args.build_number}",
            f"--dart-define-from-file={config}",
        ], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
