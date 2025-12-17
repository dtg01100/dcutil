#!/usr/bin/env python3
"""Command-line helpers for feature operations used by shell wrappers.

Provides a small, well-tested surface so Bash can delegate complex JSON
mutations to Python (safer than ad-hoc jq/sed/awk when logic grows).

Operations:
  add_to_config <config_path> <feature_spec> [options_json]
  remove_from_config <config_path> <feature_name>
  apply_changes <config_path>    (reads newline-separated selected ids from stdin)

"""
from __future__ import annotations

import json
import os
import sys
from typing import Dict, List, Any

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)

try:
    from json_utils import read_devcontainer_config, write_devcontainer_config
except Exception as e:  # pragma: no cover - defensive
    print(f"Error importing json utilities: {e}", file=sys.stderr)
    sys.exit(2)


def canonicalize_spec(spec: str) -> str:
    """Return a canonical feature id for a given spec.

    If the caller provided a short name (e.g., 'git'), convert to
    'ghcr.io/devcontainers/features/git'. Preserve registry if present.
    """
    spec = spec.strip()
    if not spec:
        return spec
    # If appears to be a full id (contains '/'), assume it's correct
    if "/" in spec:
        return spec
    # Otherwise, assume official namespace
    return f"ghcr.io/devcontainers/features/{spec}"


def add_to_config(path: str, feature_spec: str, options_json: str | None = None) -> int:
    cfg = read_devcontainer_config(path)
    if not isinstance(cfg, dict):
        print("Config not a JSON object", file=sys.stderr)
        return 2

    # Normalize features section to object
    features = cfg.get("features")
    if features is None or isinstance(features, list):
        # Convert list/None to object mapping preserving entries
        out = {}
        if isinstance(features, list):
            for e in features:
                if isinstance(e, str):
                    out[e] = {}
                elif isinstance(e, dict):
                    # dict might be {id: {..}} or {"id": ..}
                    if "id" in e:
                        out[e["id"]] = e
                    else:
                        # keys as feature ids
                        for k, v in e.items():
                            out[k] = v
        cfg["features"] = out

    feature_id = canonicalize_spec(feature_spec)
    opts: Dict[str, Any] = {}
    if options_json:
        try:
            opts = json.loads(options_json)
        except Exception:
            # If options_json is not valid JSON, treat as empty
            opts = {}

    cfg.setdefault("features", {})
    cfg["features"][feature_id] = opts

    ok = write_devcontainer_config(path, cfg)
    return 0 if ok else 1


def remove_from_config(path: str, feature_name: str) -> int:
    cfg = read_devcontainer_config(path)
    if not isinstance(cfg, dict):
        print("Config not a JSON object", file=sys.stderr)
        return 2

    features = cfg.get("features")
    if features is None:
        # nothing to remove
        return 0

    # Helper to match a feature key against a name
    def matches(key: str, name: str) -> bool:
        if key == name:
            return True
        if key.endswith("/" + name):
            return True
        # consider version suffixes, e.g., ghcr.io/.../git:1
        if key.split(":")[0].endswith("/" + name):
            return True
        return False

    if isinstance(features, dict):
        to_del = [k for k in features.keys() if matches(k, feature_name)]
        for k in to_del:
            del cfg["features"][k]
    elif isinstance(features, list):
        new_list: List[Any] = []
        for e in features:
            if isinstance(e, str):
                if not matches(e, feature_name):
                    new_list.append(e)
            elif isinstance(e, dict):
                # support object entries with id
                if "id" in e and matches(e["id"], feature_name):
                    continue
                # or single-key objects
                keys = list(e.keys())
                if len(keys) == 1 and matches(keys[0], feature_name):
                    continue
                new_list.append(e)
        cfg["features"] = new_list

    ok = write_devcontainer_config(path, cfg)
    return 0 if ok else 1


def apply_changes(path: str, selected: List[str]) -> int:
    # Build sets of short names (last path component) for comparison
    cfg = read_devcontainer_config(path)
    if not isinstance(cfg, dict):
        print("Config not a JSON object", file=sys.stderr)
        return 2

    existing_names = set()
    features = cfg.get("features")
    if isinstance(features, dict):
        for k in features.keys():
            short = k.split("/")[-1].split(":")[0]
            existing_names.add(short)
    elif isinstance(features, list):
        for e in features:
            if isinstance(e, str):
                short = e.split("/")[-1].split(":")[0]
                existing_names.add(short)
            elif isinstance(e, dict):
                if "id" in e:
                    short = e["id"].split("/")[-1].split(":")[0]
                    existing_names.add(short)
                else:
                    keys = list(e.keys())
                    if keys:
                        short = keys[0].split("/")[-1].split(":")[0]
                        existing_names.add(short)

    sel_names = set(s.split("/")[-1].split(":")[0] for s in selected if s)

    to_add = sorted(sel_names - existing_names)
    to_remove = sorted(existing_names - sel_names)

    if not to_add and not to_remove:
        # nothing to do
        return 0

    # Ensure features becomes an object mapping
    if not isinstance(cfg.get("features"), dict):
        # Convert list to dict preserving options
        out = {}
        if isinstance(cfg.get("features"), list):
            for e in cfg.get("features", []):
                if isinstance(e, str):
                    out[e] = {}
                elif isinstance(e, dict):
                    if "id" in e:
                        out[e["id"]] = e
                    else:
                        for k, v in e.items():
                            out[k] = v
        cfg["features"] = out

    for name in to_add:
        fid = canonicalize_spec(name)
        cfg["features"][fid] = {}

    # Remove by matching short names
    keys = list(cfg["features"].keys())
    for k in keys:
        short = k.split("/")[-1].split(":")[0]
        if short in to_remove:
            del cfg["features"][k]

    ok = write_devcontainer_config(path, cfg)
    return 0 if ok else 1


def main(argv: List[str]) -> int:
    if len(argv) < 2:
        print("Usage: feature_cli.py <op> [args...]", file=sys.stderr)
        return 2
    op = argv[1]
    if op == "add_to_config":
        if len(argv) < 4:
            print("add_to_config <config_path> <feature_spec> [options_json]", file=sys.stderr)
            return 2
        cfg = argv[2]
        spec = argv[3]
        opts = argv[4] if len(argv) > 4 else None
        return add_to_config(cfg, spec, opts)
    elif op == "remove_from_config":
        if len(argv) < 4:
            print("remove_from_config <config_path> <feature_name>", file=sys.stderr)
            return 2
        return remove_from_config(argv[2], argv[3])
    elif op == "apply_changes":
        if len(argv) < 3:
            print("apply_changes <config_path>", file=sys.stderr)
            return 2
        path = argv[2]
        selected = [line.strip() for line in sys.stdin.read().splitlines() if line.strip()]
        return apply_changes(path, selected)
    else:
        print(f"Unknown op: {op}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
