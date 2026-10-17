#!/usr/bin/env python3
"""Checks that every local image and link in the README actually exists.

GitHub renders a broken image as an empty box and a broken link as a 404, so a
typo in a path is invisible until someone opens the repo. Run this before every
push:

    python3 tools/check_readme_links.py [README.md ...]

Exits non-zero and lists the offenders when something is missing.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MARKDOWN_IMAGE = re.compile(r"!\[[^\]]*\]\(([^)\s]+)")
HTML_IMAGE = re.compile(r"<img[^>]*\bsrc=\"([^\"]+)\"", re.IGNORECASE)
MARKDOWN_LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)")


def targets(text):
    for pattern in (MARKDOWN_IMAGE, HTML_IMAGE, MARKDOWN_LINK):
        for match in pattern.finditer(text):
            yield match.group(1)


def is_local(url):
    if url.startswith(("http://", "https://", "mailto:", "#", "data:")):
        return False
    return True


def main(paths):
    if not paths:
        paths = ["README.md"]
    missing = []
    checked = 0
    for relative in paths:
        full = os.path.join(ROOT, relative)
        if not os.path.exists(full):
            missing.append((relative, "<the file itself>"))
            continue
        with open(full, encoding="utf-8") as handle:
            text = handle.read()
        for url in targets(text):
            if not is_local(url):
                continue
            target = url.split("#")[0]
            if not target:
                continue
            checked += 1
            if not os.path.exists(os.path.join(ROOT, target)):
                missing.append((relative, url))

    print("checked %d local image/link targets in %s" % (checked, ", ".join(paths)))
    if missing:
        print("MISSING:")
        for source, url in missing:
            print("  %s -> %s" % (source, url))
        return 1
    print("all local targets resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
