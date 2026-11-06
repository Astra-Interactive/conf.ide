"""Split an audit folder's manifest.tsv into shards, one per session-auditor run.

Usage: python3 -I shard.py <audit_dir> [--sessions N] [--subagents N] [--cwd TEXT] [--since YYYY-MM-DD]
Interactive sessions of every tool go to shards/session-<i>.tsv, subagent transcripts to
shards/subagent-<i>.tsv. Rows of the other kinds (command-only, unreadable, broken) stay in the manifest
only. A project's rows stay in one shard unless the project alone outweighs its share. An audit folder
is sharded once: progress logs refer to the row numbers.
"""
import argparse
import collections
import csv
import os
import sys

SESSION_BIG_SHARE = 0.25
SUBAGENT_BIG_SHARE = 0.15
COLUMNS = ("n", "digest", "tool", "kind", "cwd", "started", "bytes", "lines", "user_msgs", "errors", "interrupts")


def parse_args():
    parser = argparse.ArgumentParser(description="Split manifest.tsv into shards for session-auditor runs.")
    parser.add_argument("audit_dir", help="the folder extract.py wrote")
    parser.add_argument("--sessions", type=int, default=2, help="shards of interactive sessions (default 2)")
    parser.add_argument("--subagents", type=int, default=2, help="shards of subagent transcripts (default 2)")
    parser.add_argument("--cwd", default="", help="keep only rows whose cwd contains this text")
    parser.add_argument("--since", default="", help="keep only rows started on or after this date (YYYY-MM-DD)")
    return parser.parse_args()


def line_count(path):
    with open(path, errors="replace") as handle:
        return sum(1 for _ in handle)


def pack(items, count, big_share):
    groups = collections.defaultdict(list)
    for row in items:
        groups[(row["tool"], row["kind"], row["cwd"])].append(row)
    bins = [[] for _ in range(count)]
    size = [0] * count
    total_all = sum(row["bytes"] for row in items)
    big = []
    for _, group in sorted(groups.items(), key=lambda kv: -sum(x["bytes"] for x in kv[1])):
        total = sum(x["bytes"] for x in group)
        if total > total_all * big_share:
            big.extend(group)
            continue
        index = size.index(min(size))
        bins[index].extend(group)
        size[index] += total
    for row in sorted(big, key=lambda x: -x["bytes"]):
        index = size.index(min(size))
        bins[index].append(row)
        size[index] += row["bytes"]
    return bins


def write_shard(path, items):
    items.sort(key=lambda r: (r["tool"], r["kind"], r["cwd"], r["started"]))
    with open(path, "w") as handle:
        handle.write("\t".join(COLUMNS) + "\n")
        for index, row in enumerate(items, 1):
            row["n"] = index
            handle.write("\t".join(str(row[column]) for column in COLUMNS) + "\n")


def main():
    args = parse_args()
    audit = os.path.abspath(args.audit_dir)
    with open(os.path.join(audit, "manifest.tsv")) as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    rows = [r for r in rows if args.cwd in r["cwd"] and r["started"] >= args.since]
    skipped = collections.Counter(r["kind"] for r in rows if r["kind"] not in ("session", "subagent"))
    rows = [r for r in rows if r["kind"] in ("session", "subagent")]
    for row in rows:
        path = os.path.join(audit, row["digest"])
        row["bytes"] = os.path.getsize(path)
        row["lines"] = line_count(path)
    shard_dir = os.path.join(audit, "shards")
    if os.path.isdir(shard_dir) and any(name.endswith(".tsv") for name in os.listdir(shard_dir)):
        sys.exit(f"{shard_dir} already holds shards; progress logs refer to their row numbers. Shard once per audit folder.")
    os.makedirs(shard_dir, exist_ok=True)
    plan = (
        ("session", args.sessions, SESSION_BIG_SHARE),
        ("subagent", args.subagents, SUBAGENT_BIG_SHARE),
    )
    for kind, count, big_share in plan:
        items = [r for r in rows if r["kind"] == kind]
        if count < 1:
            if items:
                skipped[kind] += len(items)
            continue
        for index, shard in enumerate(pack(items, count, big_share), 1):
            if not shard:
                continue
            path = os.path.join(audit, "shards", f"{kind}-{index}.tsv")
            write_shard(path, shard)
            lines = sum(r["lines"] for r in shard)
            print(f"{os.path.relpath(path, audit)}: {len(shard)} rows, {lines} digest lines")
    if skipped:
        print("not sharded: " + ", ".join(f"{kind} {count}" for kind, count in sorted(skipped.items())))


if __name__ == "__main__":
    main()
