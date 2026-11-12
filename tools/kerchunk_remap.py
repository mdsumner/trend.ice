#!/usr/bin/env python3
"""Remap the file paths in a kerchunk Parquet reference store.

Writes a new store (never edits the source): every file is copied, and in
each refs.*.parq the `path` column has its prefix rewritten by the first
matching rule. Inline chunks (raw, no path) are untouched.

    python tools/kerchunk_remap.py SRC DST                # default rule: NCI THREDDS -> /g/data
    python tools/kerchunk_remap.py SRC DST --rule FROM=TO [--rule FROM=TO ...]
    python tools/kerchunk_remap.py SRC --scan             # list path prefixes only

After remapping, --check samples paths in DST and confirms the files exist
and each referenced byte range lies inside its file.

Destined for raad.virtualize; lives here while trend.ice needs it.
"""
import argparse
import os
import random
import shutil
import sys
from collections import Counter

import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.parquet as pq

DEFAULT_RULES = [
    ("https://thredds.nci.org.au/thredds/fileServer/", "/g/data/"),
    ("http://thredds.nci.org.au/thredds/fileServer/", "/g/data/"),
    ("https://thredds.nci.org.au/thredds/dodsC/", "/g/data/"),
]


def ref_files(root):
    for d, _, fs in os.walk(root):
        for f in fs:
            if f.startswith("refs.") and f.endswith(".parq"):
                yield os.path.join(d, f)


def prefix_of(p, depth=6):
    parts = p.split("/")
    return "/".join(parts[:depth]) + "/"


def scan(root, n=20):
    c = Counter()
    for f in ref_files(root):
        t = pq.read_table(f, columns=["path"])
        for p in pc.unique(t["path"]).to_pylist():
            if p is not None:
                c[prefix_of(p)] += 1
    for k, v in c.most_common(n):
        print(f"{v:8d}  {k}")
    return c


def remap_table(t, rules):
    path = t["path"]
    out = path
    valid = pc.is_valid(path)
    hit_any = None
    for frm, to in rules:
        hit = pc.fill_null(pc.starts_with(path, frm), False)
        if hit_any is not None:
            hit = pc.and_(hit, pc.invert(hit_any))
        new = pc.binary_join_element_wise(pa.scalar(to), pc.utf8_slice_codeunits(path, len(frm)), "")
        out = pc.if_else(hit, new, out)
        hit_any = hit if hit_any is None else pc.or_(hit_any, hit)
    unmatched = pc.sum(pc.and_(valid, pc.invert(hit_any))).as_py() or 0
    i = t.schema.get_field_index("path")
    return t.set_column(i, t.schema.field(i), out), unmatched


def remap(src, dst, rules):
    if os.path.exists(dst):
        sys.exit(f"{dst} exists; refusing to overwrite")
    shutil.copytree(src, dst, ignore=shutil.ignore_patterns("refs.*.parq"))
    nfile = nunm = 0
    for f in ref_files(src):
        t = pq.read_table(f)
        t2, unm = remap_table(t, rules)
        out = os.path.join(dst, os.path.relpath(f, src))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        pq.write_table(t2, out, compression="zstd")
        nfile += 1
        nunm += unm
    print(f"remapped {nfile} ref files; {nunm} paths matched no rule (left as is)")
    return nunm


def check(root, n=2000, seed=1):
    random.seed(seed)
    files = list(ref_files(root))
    bad = []
    seen = {}
    picks = 0
    for f in random.sample(files, min(len(files), 200)):
        t = pq.read_table(f, columns=["path", "offset", "size"]).to_pylist()
        rows = [r for r in t if r["path"] is not None]
        for r in random.sample(rows, min(len(rows), max(1, n // 200))):
            picks += 1
            p = r["path"]
            if p not in seen:
                seen[p] = os.path.getsize(p) if os.path.exists(p) else None
            sz = seen[p]
            if sz is None:
                bad.append(("missing", p))
            elif r["offset"] + r["size"] > sz:
                bad.append(("out of range", p))
    print(f"checked {picks} refs in {len(seen)} files: {len(bad)} problems")
    for b in bad[:10]:
        print("  ", *b)
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--rule", action="append", default=[], help="FROM=TO prefix rule")
    ap.add_argument("--scan", action="store_true")
    ap.add_argument("--check", action="store_true", help="check DST (or SRC with --scan) after remap")
    a = ap.parse_args()
    if a.scan:
        scan(a.src)
        return
    rules = [tuple(r.split("=", 1)) for r in a.rule] or DEFAULT_RULES
    unm = remap(a.src, a.dst, rules)
    if a.check:
        bad = check(a.dst)
        sys.exit(1 if (bad or unm) else 0)


if __name__ == "__main__":
    main()
