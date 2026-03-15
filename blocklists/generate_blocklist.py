#!/usr/bin/env python3
"""
Merge StevenBlack/hosts and polarhive/arceo blocklists into a single
sorted, deduplicated domain list for Dumb Browser.
"""

import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

HOSTS_FILES = [
    os.path.join(SCRIPT_DIR, "StevenBlack-hosts/alternates/fakenews-gambling-porn-social/hosts"),
    os.path.join(SCRIPT_DIR, "arceo/lists/all.txt"),
]

# Domains to never block (localhost entries, etc.)
EXCLUDE = frozenset([
    "localhost",
    "localhost.localdomain",
    "local",
    "broadcasthost",
    "0.0.0.0",
    "ip6-localhost",
    "ip6-loopback",
    "ip6-localnet",
    "ip6-mcastprefix",
    "ip6-allnodes",
    "ip6-allrouters",
    "ip6-allhosts",
])


def extract_domains(path):
    domains = set()
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) >= 2 and parts[0] in ("0.0.0.0", "127.0.0.1"):
                domain = parts[1].lower()
                if domain not in EXCLUDE:
                    domains.add(domain)
    return domains


def main():
    all_domains = set()
    for path in HOSTS_FILES:
        if not os.path.exists(path):
            print(f"Warning: {path} not found, skipping", file=sys.stderr)
            continue
        domains = extract_domains(path)
        print(f"  {path}: {len(domains)} domains", file=sys.stderr)
        all_domains |= domains

    sorted_domains = sorted(all_domains)
    print(f"  Total unique domains: {len(sorted_domains)}", file=sys.stderr)

    output = os.path.join(SCRIPT_DIR, "..", "blocked_domains.txt")
    with open(output, "w") as f:
        for domain in sorted_domains:
            f.write(domain + "\n")
    print(f"  Written to: {output}", file=sys.stderr)


if __name__ == "__main__":
    main()
