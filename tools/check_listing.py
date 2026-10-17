#!/usr/bin/env python3
"""Lints the App Store listing before you paste it into App Store Connect.

Checks field limits, empty required fields, every term on the listing's own
"avoid" list (the original app and its owner), and keywords that repeat the
title or subtitle and therefore waste characters.

    python3 tools/check_listing.py replica/launch/listing.json

Exits non-zero when App Store Connect would reject a field.
"""
import json
import re
import sys

LIMITS = {
    "name": 30,
    "subtitle": 30,
    "promotional_text": 170,
    "description": 4000,
    "keywords": 100,
    "whats_new": 4000,
}
REQUIRED = ["name", "subtitle", "description", "keywords"]


def main(path):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    store = data.get("app_store", {})
    avoid = [term for term in data.get("avoid", []) if term.strip()]
    errors = []
    warnings = []

    print("field                 used / limit")
    for field, limit in LIMITS.items():
        value = store.get(field, "") or ""
        used = len(value)
        state = "ok" if used <= limit else "OVER"
        print("  %-18s %4d / %-5d %s" % (field, used, limit, state))
        if used > limit:
            errors.append("%s is %d characters, %d over the limit" % (field, used, used - limit))

    for field in REQUIRED:
        if not (store.get(field) or "").strip():
            errors.append("%s is empty" % field)

    haystack = " ".join(str(store.get(field, "")) for field in LIMITS)
    for term in avoid:
        if re.search(r"\b%s\b" % re.escape(term), haystack, re.IGNORECASE):
            errors.append('listing mentions "%s", which is on the avoid list' % term)

    title = "%s %s" % (store.get("name", ""), store.get("subtitle", ""))
    keywords = [word.strip() for word in (store.get("keywords", "") or "").split(",") if word.strip()]
    wasted = [word for word in keywords if word.lower() in title.lower()]
    if wasted:
        warnings.append("keywords already in the name or subtitle, so they waste characters: " + ", ".join(wasted))
    if len(set(word.lower() for word in keywords)) != len(keywords):
        warnings.append("duplicate keywords in the keyword field")

    print()
    for warning in warnings:
        print("WARN  " + warning)
    for error in errors:
        print("ERROR " + error)
    if not errors and not warnings:
        print("No issues.")
    print()
    print("%d errors, %d warnings" % (len(errors), len(warnings)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "replica/launch/listing.json"))
