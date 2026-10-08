#!/usr/bin/env python3
"""Validate local Firebase client files without printing keys or sending requests."""
import argparse
import json
import plistlib
from pathlib import Path


def inspect(ios, android):
    results, projects = [], set()

    def check(path, label, reader, validate):
        if not path.is_file():
            results.append(("MISSING", label))
            return
        try:
            with path.open("rb") as handle:
                project = validate(reader(handle))
            if not project:
                raise ValueError()
            projects.add(project)
            results.append(("OK", label))
        except (ValueError, KeyError, TypeError, AttributeError, OSError, plistlib.InvalidFileException):
            results.append(("INVALID", label))

    def apple(data):
        if data["BUNDLE_ID"] != "com.Kevin.Opportunity313":
            raise ValueError()
        if not all(isinstance(data[k], str) and data[k].strip() for k in
                   ("GOOGLE_APP_ID", "GCM_SENDER_ID", "API_KEY", "PROJECT_ID")):
            raise ValueError()
        return data["PROJECT_ID"]

    check(ios / "Opportunity313/GoogleService-Info.plist", "iOS client", plistlib.load, apple)
    for variant, package in (("debug", "com.opportunity313.android.debug"),
                             ("release", "com.opportunity313.android")):
        path = android / f"app/src/{variant}/google-services.json"
        if not path.is_file():
            path = android / "app/google-services.json"

        def android_client(data):
            info = data["project_info"]
            if not all(isinstance(info[k], str) and info[k].strip() for k in ("project_id", "project_number")):
                raise ValueError()
            for client in data["client"]:
                details = client["client_info"]
                if details["android_client_info"]["package_name"] == package:
                    if not details.get("mobilesdk_app_id") or not any(k.get("current_key") for k in client.get("api_key", [])):
                        raise ValueError()
                    return info["project_id"]
            raise ValueError()

        check(path, f"Android {variant} client", json.load, android_client)
    if len(projects) > 1:
        results.append(("INVALID", "Client files must use the same Firebase project for this broadcast setup"))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ios-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--android-root", type=Path)
    parser.add_argument("--require-config", action="store_true", help="Fail for missing files as well as invalid files")
    args = parser.parse_args()
    results = inspect(args.ios_root, args.android_root or args.ios_root.parent / "Opportunity313Android")
    for status, label in results:
        print(f"{status}: {label}")
    print("Checks local client structure/IDs only; does not verify server secrets, APNs, or delivery.")
    return int(any(status == "INVALID" or (args.require_config and status == "MISSING") for status, _ in results))


if __name__ == "__main__":
    raise SystemExit(main())
