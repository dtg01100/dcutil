import json
import os
from pathlib import Path
import pytest

from lib import json_utils


class TestReadDevcontainerConfig:
    def test_read_valid_config(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        test_data = {"name": "test", "features": {"git": {}}}
        config_path.write_text(json.dumps(test_data))

        result = json_utils.read_devcontainer_config(str(config_path))

        assert result == test_data

    def test_read_empty_config(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text("{}")

        result = json_utils.read_devcontainer_config(str(config_path))

        assert result == {}

    def test_read_missing_file(self, tmp_path):
        config_path = tmp_path / "nonexistent.json"

        result = json_utils.read_devcontainer_config(str(config_path))

        assert result == {}

    def test_read_invalid_json(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text("{invalid json}")

        result = json_utils.read_devcontainer_config(str(config_path))

        assert result == {}

    def test_read_empty_file(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text("")

        result = json_utils.read_devcontainer_config(str(config_path))

        assert result == {}


class TestWriteDevcontainerConfig:
    def test_write_new_config(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        test_data = {"name": "test", "features": {}}

        result = json_utils.write_devcontainer_config(str(config_path), test_data)

        assert result is True
        assert json.loads(config_path.read_text()) == test_data

    def test_write_creates_backup(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        original_data = {"name": "original"}
        config_path.write_text(json.dumps(original_data))

        new_data = {"name": "updated"}
        result = json_utils.write_devcontainer_config(str(config_path), new_data)

        assert result is True
        backup_path = Path(str(config_path) + ".backup")
        assert backup_path.exists()
        assert json.loads(backup_path.read_text()) == original_data

    def test_write_no_backup_for_new_file(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        test_data = {"name": "test"}

        result = json_utils.write_devcontainer_config(str(config_path), test_data)

        assert result is True
        backup_path = Path(str(config_path) + ".backup")
        assert not backup_path.exists()

    def test_write_to_directory_without_permission(self, tmp_path):
        config_path = tmp_path / "subdir" / "devcontainer.json"
        test_data = {"name": "test"}

        result = json_utils.write_devcontainer_config(str(config_path), test_data)

        assert result is False


class TestHasFeature:
    def test_has_feature_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/git": {}}}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_feature(
            str(config_path), "ghcr.io/devcontainers/features/git"
        )

        assert result is True

    def test_has_feature_not_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/git": {}}}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_feature(
            str(config_path), "ghcr.io/devcontainers/features/docker"
        )

        assert result is False

    def test_has_feature_no_features_section(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"name": "test"}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_feature(str(config_path), "some-feature")

        assert result is False

    def test_has_feature_empty_features(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {}}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_feature(str(config_path), "some-feature")

        assert result is False


class TestAddFeature:
    def test_add_feature_new_config(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text(json.dumps({"name": "test"}))

        result = json_utils.add_feature(
            str(config_path), "ghcr.io/devcontainers/features/git"
        )

        assert result is True
        config = json.loads(config_path.read_text())
        assert "features" in config
        assert "ghcr.io/devcontainers/features/git" in config["features"]
        assert config["features"]["ghcr.io/devcontainers/features/git"] == {}

    def test_add_feature_with_options(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text(json.dumps({"name": "test"}))

        options = {"version": "2.0.0", "installCmd": "make install"}
        result = json_utils.add_feature(
            str(config_path), "ghcr.io/devcontainers/features/git", options
        )

        assert result is True
        config = json.loads(config_path.read_text())
        assert config["features"]["ghcr.io/devcontainers/features/git"] == options

    def test_add_feature_to_existing(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/docker": {}}}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.add_feature(
            str(config_path), "ghcr.io/devcontainers/features/git"
        )

        assert result is True
        config = json.loads(config_path.read_text())
        assert "ghcr.io/devcontainers/features/docker" in config["features"]
        assert "ghcr.io/devcontainers/features/git" in config["features"]

    def test_add_feature_empty_config_path(self, tmp_path):
        result = json_utils.add_feature("", "some-feature")

        assert result is False

    def test_add_feature_empty_feature_id(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text(json.dumps({}))

        result = json_utils.add_feature(str(config_path), "")

        assert result is False

    def test_add_feature_nonexistent_file(self, tmp_path):
        config_path = tmp_path / "nonexistent.json"

        result = json_utils.add_feature(str(config_path), "some-feature")

        assert result is False

    def test_add_feature_updates_existing(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {
            "features": {"ghcr.io/devcontainers/features/git": {"version": "1.0"}}
        }
        config_path.write_text(json.dumps(config_data))

        result = json_utils.add_feature(
            str(config_path), "ghcr.io/devcontainers/features/git", {"version": "2.0"}
        )

        assert result is True
        config = json.loads(config_path.read_text())
        assert config["features"]["ghcr.io/devcontainers/features/git"] == {
            "version": "2.0"
        }


class TestHasMount:
    def test_has_mount_string_format(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"mounts": ["type=bind,source=/host/path,target=/container/path"]}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_mount(str(config_path), "/host/path")

        assert result is True

    def test_has_mount_dict_format(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {
            "mounts": [
                {"type": "bind", "source": "/host/path", "target": "/container/path"}
            ]
        }
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_mount(str(config_path), "/host/path")

        assert result is True

    def test_has_mount_not_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {
            "mounts": ["type=bind,source=/other/path,target=/container/path"]
        }
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_mount(str(config_path), "/host/path")

        assert result is False

    def test_has_mount_no_mounts_section(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"name": "test"}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_mount(str(config_path), "/some/path")

        assert result is False

    def test_has_mount_partial_path_not_match(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {
            "mounts": ["type=bind,source=/workspace/project,target=/project"]
        }
        config_path.write_text(json.dumps(config_data))

        result = json_utils.has_mount(str(config_path), "/workspace")

        assert result is True


class TestAddMount:
    def test_add_mount_new(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text(json.dumps({}))

        result = json_utils.add_mount(str(config_path), "/host/path", "/container/path")

        assert result is True
        config = json.loads(config_path.read_text())
        assert "mounts" in config
        assert "type=bind,source=/host/path,target=/container/path" in config["mounts"]

    def test_add_mount_with_type(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text(json.dumps({}))

        result = json_utils.add_mount(
            str(config_path), "/host/path", "/container/path", "volume"
        )

        assert result is True
        config = json.loads(config_path.read_text())
        assert (
            "type=volume,source=/host/path,target=/container/path" in config["mounts"]
        )

    def test_add_mount_to_existing(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"mounts": ["type=bind,source=/existing,target=/container"]}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.add_mount(str(config_path), "/host/path", "/container/path")

        assert result is True
        config = json.loads(config_path.read_text())
        assert len(config["mounts"]) == 2
        assert "type=bind,source=/existing,target=/container" in config["mounts"]
        assert "type=bind,source=/host/path,target=/container/path" in config["mounts"]

    def test_add_mount_no_duplicates(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"mounts": ["type=bind,source=/host/path,target=/container/path"]}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.add_mount(str(config_path), "/host/path", "/container/path")

        assert result is True
        config = json.loads(config_path.read_text())
        assert (
            config["mounts"].count("type=bind,source=/host/path,target=/container/path")
            == 1
        )


class TestGetContainerUser:
    def test_get_container_user_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"containerUser": "root"}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.get_container_user(str(config_path))

        assert result == "root"

    def test_get_container_user_not_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"name": "test"}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.get_container_user(str(config_path))

        assert result == "vscode"

    def test_get_container_user_empty(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"containerUser": ""}
        config_path.write_text(json.dumps(config_data))

        result = json_utils.get_container_user(str(config_path))

        assert result == ""


class TestValidateConfigStructureBasic:
    def test_validate_valid_config(self):
        config_data = {"name": "test", "features": {}, "mounts": []}

        result = json_utils.validate_config_structure_basic(config_data)

        assert result is True

    def test_validate_empty_config(self):
        config_data = {}

        result = json_utils.validate_config_structure_basic(config_data)

        assert result is True

    def test_validate_not_dict(self):
        config_data = "not a dict"

        result = json_utils.validate_config_structure_basic(config_data)

        assert result is False

    def test_validate_features_not_dict(self):
        config_data = {"features": "not a dict"}

        result = json_utils.validate_config_structure_basic(config_data)

        assert result is False

    def test_validate_mounts_not_list(self):
        config_data = {"mounts": "not a list"}

        result = json_utils.validate_config_structure_basic(config_data)

        assert result is False


class TestValidateConfigStructure:
    def test_validate_file_valid_config(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"name": "test", "features": {}, "mounts": []}
        config_path.write_text(json.dumps(config_data))

        is_valid, issues = json_utils.validate_config_structure(str(config_path))

        assert is_valid is True
        assert issues == []

    def test_validate_file_empty_config(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {}
        config_path.write_text(json.dumps(config_data))

        is_valid, issues = json_utils.validate_config_structure(str(config_path))

        assert is_valid is True
        assert issues == []

    def test_validate_file_missing(self, tmp_path):
        config_path = tmp_path / "nonexistent.json"

        is_valid, issues = json_utils.validate_config_structure(str(config_path))

        assert is_valid is True
        assert issues == []

    def test_validate_file_invalid_json(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text("not valid json")

        is_valid, issues = json_utils.validate_config_structure(str(config_path))

        assert is_valid is True
        assert issues == []

    def test_validate_file_features_not_dict(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": ["not", "a", "dict"]}
        config_path.write_text(json.dumps(config_data))

        is_valid, issues = json_utils.validate_config_structure(str(config_path))

        assert is_valid is False
        assert any("Features" in issue for issue in issues)

    def test_validate_file_mounts_not_list(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"mounts": {"source": "path", "target": "path"}}
        config_path.write_text(json.dumps(config_data))

        is_valid, issues = json_utils.validate_config_structure(str(config_path))

        assert is_valid is False
        assert any("Mounts" in issue for issue in issues)


class TestIntegration:
    def test_full_workflow(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text(
            json.dumps({"name": "test", "containerUser": "developer"})
        )

        assert json_utils.has_feature(str(config_path), "git") is False
        assert (
            json_utils.add_feature(
                str(config_path),
                "ghcr.io/devcontainers/features/git",
                {"version": "1.0"},
            )
            is True
        )
        assert (
            json_utils.has_feature(
                str(config_path), "ghcr.io/devcontainers/features/git"
            )
            is True
        )

        assert json_utils.has_mount(str(config_path), "/workspace") is False
        assert (
            json_utils.add_mount(str(config_path), "/workspace", "/workspaces") is True
        )
        assert json_utils.has_mount(str(config_path), "/workspace") is True

        assert json_utils.get_container_user(str(config_path)) == "developer"

        is_valid, issues = json_utils.validate_config_structure(str(config_path))
        assert is_valid is True
