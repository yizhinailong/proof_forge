#!/usr/bin/env python3
"""PF-P2-01: Product catalog discovery gate.

Every Examples/Product/*.lean file must appear in Examples/Product/catalog.json.
Uncatalogued or missing catalog entries fail the gate.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PRODUCT = REPO / "Examples" / "Product"
CATALOG = PRODUCT / "catalog.json"


def main() -> int:
    if not CATALOG.is_file():
        print(f"missing product catalog: {CATALOG}", file=sys.stderr)
        return 1
    data = json.loads(CATALOG.read_text())
    if data.get("kind") != "proof-forge-product-catalog":
        print("catalog kind must be proof-forge-product-catalog", file=sys.stderr)
        return 1
    listed = {entry["file"] for entry in data.get("sources", [])}
    on_disk = {p.name for p in PRODUCT.glob("*.lean") if not p.name.startswith("_")}
    # Ignore non-source helpers if any
    missing = sorted(on_disk - listed)
    extra = sorted(listed - on_disk)
    if missing:
        print("uncatalogued Product sources:", ", ".join(missing), file=sys.stderr)
        print("add them to Examples/Product/catalog.json (PF-P2-01)", file=sys.stderr)
        return 1
    if extra:
        print("catalog lists missing files:", ", ".join(extra), file=sys.stderr)
        return 1
    # Basic field checks
    for entry in data["sources"]:
        for key in ("authoring", "kind", "targets", "gates"):
            if key not in entry:
                print(f"{entry.get('file')}: missing field {key}", file=sys.stderr)
                return 1
        if entry["authoring"] not in ("contract_source", "TokenSpec", "facade"):
            print(f"{entry['file']}: bad authoring {entry['authoring']}", file=sys.stderr)
            return 1
    runtime = [e["file"] for e in data["sources"] if e.get("runtimeTriad")]
    print(
        f"product-catalog: ok ({len(listed)} sources; runtimeTriad={', '.join(runtime) or 'none'})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
