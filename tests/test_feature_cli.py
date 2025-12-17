import json
import os
import tempfile
from pathlib import Path

import pytest

from lib import feature_cli


def read_cfg(path: Path):
    with open(path, "r") as f:
        return json.load(f)


def test_add_to_new_config(tmp_path: Path):
    cfg_path = tmp_path / "devcontainer.json"
    rc = feature_cli.add_to_config(str(cfg_path), "git", None)
    assert rc == 0
    cfg = read_cfg(cfg_path)
    assert "features" in cfg
    assert "ghcr.io/devcontainers/features/git" in cfg["features"]


def test_add_to_array_converts_to_object(tmp_path: Path):
    cfg_path = tmp_path / "devcontainer.json"
    cfg_path.write_text(json.dumps({"features": ["ghcr.io/devcontainers/features/git"]}))
    rc = feature_cli.add_to_config(str(cfg_path), "docker", None)
    assert rc == 0
    cfg = read_cfg(cfg_path)
    assert isinstance(cfg["features"], dict)
    assert "ghcr.io/devcontainers/features/docker" in cfg["features"]


def test_remove_from_config_object_and_list(tmp_path: Path):
    cfg_path = tmp_path / "devcontainer.json"
    # Test object removal
    cfg_path.write_text(json.dumps({"features": {"ghcr.io/devcontainers/features/git": {}, "ghcr.io/devcontainers/features/docker": {}}}))
    rc = feature_cli.remove_from_config(str(cfg_path), "git")
    assert rc == 0
    cfg = read_cfg(cfg_path)
    assert "ghcr.io/devcontainers/features/git" not in cfg["features"]

    # Test list removal
    cfg_path.write_text(json.dumps({"features": ["ghcr.io/devcontainers/features/git", "ghcr.io/devcontainers/features/docker"]}))
    rc = feature_cli.remove_from_config(str(cfg_path), "git")
    assert rc == 0
    cfg = read_cfg(cfg_path)
    # After removal, remaining features should not include git
    if isinstance(cfg["features"], list):
        shorts = [s.split("/")[-1].split(":")[0] for s in cfg["features"] if isinstance(s, str)]
        assert "git" not in shorts


def test_apply_changes_adds_and_removes(tmp_path: Path):
    cfg_path = tmp_path / "devcontainer.json"
    # Start with git only
    cfg_path.write_text(json.dumps({"features": ["ghcr.io/devcontainers/features/git"]}))
    # Select docker only -> should remove git and add docker
    rc = feature_cli.apply_changes(str(cfg_path), ["docker"])
    assert rc == 0
    cfg = read_cfg(cfg_path)
    # Features should be object and contain docker but not git
    assert isinstance(cfg["features"], dict)
    assert any(k.endswith("/docker") for k in cfg["features"].keys())
    assert not any(k.endswith("/git") for k in cfg["features"].keys())
