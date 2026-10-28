#!/usr/bin/env python3
"""Exercise real Gradle signing with a disposable key; never use an upload key."""

import argparse
import hashlib
import os
from pathlib import Path
import secrets
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gradle", required=True, type=Path)
    parser.add_argument("--apksigner", required=True, type=Path)
    parser.add_argument("--keytool", default="keytool")
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    android = project / "android"
    if (android / "key.properties").exists():
        parser.error("Run in a checkout without private android/key.properties.")

    environment = os.environ.copy()
    for name in list(environment):
        if name.startswith("CARTY_ANDROID_"):
            environment.pop(name)
    gradle = [str(args.gradle.resolve()), "--project-dir", str(android)]

    with tempfile.TemporaryDirectory(prefix="carty-signing-check-") as directory:
        temporary = Path(directory)

        def run(label, command, env=environment, expected_error=None):
            result = subprocess.run(
                command, cwd=project, env=env,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            )
            output = result.stdout.decode("utf-8", errors="replace")
            if expected_error:
                valid = result.returncode != 0 and expected_error in output
            else:
                valid = result.returncode == 0
            if not valid:
                # Only synthetic credentials are ever passed to these commands.
                print(output)
                raise RuntimeError(f"{label} failed")
            print(f"PASS: {label}", flush=True)
            return result.stdout

        run("missing credentials reject a release build",
            gradle + [":app:assembleRelease"],
            expected_error="Android Release signing is not configured")
        run("debug builds need no release credentials",
            gradle + [":app:assembleDebug"])

        fixture = dict(environment)
        fixture.update({
            "CARTY_ANDROID_STORE_FILE": str(temporary / "verification-only.jks"),
            "CARTY_ANDROID_STORE_PASSWORD": secrets.token_hex(20),
            "CARTY_ANDROID_KEY_ALIAS": "verification-only",
            "CARTY_ANDROID_KEY_PASSWORD": secrets.token_hex(20),
        })
        partial = dict(fixture, CARTY_ANDROID_KEY_PASSWORD="")
        run("incomplete credentials are rejected",
            gradle + [":app:verifyReleaseSigning"], env=partial,
            expected_error="Missing: keyPassword")
        run("missing keystore file is rejected",
            gradle + [":app:verifyReleaseSigning"], env=fixture,
            expected_error="Android Release keystore is unavailable")
        key = fixture["CARTY_ANDROID_STORE_FILE"]
        key_flags = [
            "-keystore", key, "-alias", "verification-only",
            "-storepass:env", "CARTY_ANDROID_STORE_PASSWORD",
        ]
        run("create disposable signing fixture", [
            args.keytool, "-genkeypair", "-storetype", "JKS",
            "-keyalg", "RSA", "-keysize", "2048", "-validity", "2",
            "-dname", "CN=Carty verification only",
            "-keypass:env", "CARTY_ANDROID_KEY_PASSWORD",
        ] + key_flags, env=fixture)

        apk = project / "build/app/outputs/apk/release/app-release.apk"
        flutter_apk = project / "build/app/outputs/flutter-apk/app-release.apk"
        try:
            run("release builds use explicit credentials",
                gradle + [":app:assembleRelease"], env=fixture)
            certificate = temporary / "verification.der"
            run("export verification certificate",
                [args.keytool, "-exportcert", "-file", str(certificate)] + key_flags,
                env=fixture)
            verification = run("verify actual APK signature", [
                str(args.apksigner.resolve()), "verify", "--verbose",
                "--print-certs", str(apk),
            ]).decode("utf-8")
            digest = hashlib.sha256(certificate.read_bytes()).hexdigest()
            if f"certificate SHA-256 digest: {digest}" not in verification:
                raise RuntimeError("APK was not signed with the disposable fixture")
            print("PASS: APK certificate matches the explicit key, not the debug key")
        finally:
            # A test-signed build must not be mistaken for a distributable release.
            for artifact in (apk, flutter_apk):
                artifact.unlink(missing_ok=True)
    print("Signing verification complete; disposable key and test APK removed.")


if __name__ == "__main__":
    main()
