import json
import os
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock
import pytest

import importlib.util


def load_module_fully():
    module_path = str(Path(__file__).parent.parent / "lib" / "feature_manager.py")
    spec = importlib.util.spec_from_file_location("feature_manager", module_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules["feature_manager"] = module
    spec.loader.exec_module(module)
    return module


feature_manager = load_module_fully()


class TestGetDevcontainerConfigPath:
    def test_config_in_devcontainer_subdir(self, tmp_path):
        devcontainer_dir = tmp_path / ".devcontainer"
        devcontainer_dir.mkdir()
        config_path = devcontainer_dir / "devcontainer.json"
        config_path.write_text(json.dumps({"name": "test"}))

        result = feature_manager.get_devcontainer_config_path(str(tmp_path))

        assert result == str(config_path)

    def test_config_at_project_root(self, tmp_path):
        config_path = tmp_path / ".devcontainer.json"
        config_path.write_text(json.dumps({"name": "test"}))

        result = feature_manager.get_devcontainer_config_path(str(tmp_path))

        assert result == str(config_path)

    def test_config_not_found(self, tmp_path):
        result = feature_manager.get_devcontainer_config_path(str(tmp_path))

        assert result is None

    def test_devcontainer_subdir_priority_over_root(self, tmp_path):
        devcontainer_dir = tmp_path / ".devcontainer"
        devcontainer_dir.mkdir()
        config_path_subdir = devcontainer_dir / "devcontainer.json"
        config_path_subdir.write_text(json.dumps({"name": "subdir"}))
        config_path_root = tmp_path / ".devcontainer.json"
        config_path_root.write_text(json.dumps({"name": "root"}))

        result = feature_manager.get_devcontainer_config_path(str(tmp_path))

        assert result == str(config_path_subdir)

    def test_empty_project_dir(self, tmp_path):
        result = feature_manager.get_devcontainer_config_path(str(tmp_path))

        assert result is None


class TestFeatureExistsInDevcontainer:
    def test_feature_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/git": {}}}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.feature_exists_in_devcontainer(
            str(config_path), "ghcr.io/devcontainers/features/git"
        )

        assert result is True

    def test_feature_not_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/docker": {}}}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.feature_exists_in_devcontainer(
            str(config_path), "ghcr.io/devcontainers/features/git"
        )

        assert result is False

    def test_no_features_section(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"name": "test"}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.feature_exists_in_devcontainer(
            str(config_path), "some-feature"
        )

        assert result is False

    def test_empty_features_section(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {}}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.feature_exists_in_devcontainer(
            str(config_path), "some-feature"
        )

        assert result is False

    def test_file_not_found(self, tmp_path):
        config_path = tmp_path / "nonexistent.json"

        result = feature_manager.feature_exists_in_devcontainer(
            str(config_path), "some-feature"
        )

        assert result is False

    def test_invalid_json(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text("not valid json")

        result = feature_manager.feature_exists_in_devcontainer(
            str(config_path), "some-feature"
        )

        assert result is False

    def test_features_not_dict(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": ["not", "a", "dict"]}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.feature_exists_in_devcontainer(
            str(config_path), "some-feature"
        )

        assert result is False


class TestJsonHasFeatureFallback:
    def test_has_feature_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/git": {}}}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.json_has_feature(
            str(config_path), "ghcr.io/devcontainers/features/git"
        )

        assert result is True

    def test_has_feature_not_exists(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/docker": {}}}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.json_has_feature(
            str(config_path), "ghcr.io/devcontainers/features/git"
        )

        assert result is False

    def test_has_feature_no_features_section(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"name": "test"}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.json_has_feature(str(config_path), "some-feature")

        assert result is False

    def test_has_feature_file_not_found(self, tmp_path):
        config_path = tmp_path / "nonexistent.json"

        result = feature_manager.json_has_feature(str(config_path), "some-feature")

        assert result is False

    def test_has_feature_invalid_json(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text("not valid json")

        result = feature_manager.json_has_feature(str(config_path), "some-feature")

        assert result is False


class TestJsonAddFeatureFallback:
    def test_add_feature_new_config(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text(json.dumps({"name": "test"}))

        result = feature_manager.json_add_feature(
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
        result = feature_manager.json_add_feature(
            str(config_path), "ghcr.io/devcontainers/features/git", options
        )

        assert result is True
        config = json.loads(config_path.read_text())
        assert config["features"]["ghcr.io/devcontainers/features/git"] == options

    def test_add_feature_to_existing(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/docker": {}}}
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.json_add_feature(
            str(config_path), "ghcr.io/devcontainers/features/git"
        )

        assert result is True
        config = json.loads(config_path.read_text())
        assert "ghcr.io/devcontainers/features/docker" in config["features"]
        assert "ghcr.io/devcontainers/features/git" in config["features"]

    def test_add_feature_nonexistent_file(self, tmp_path):
        config_path = tmp_path / "nonexistent.json"

        result = feature_manager.json_add_feature(str(config_path), "some-feature")

        assert result is False

    def test_add_feature_updates_existing(self, tmp_path):
        config_path = tmp_path / "devcontainer.json"
        config_data = {
            "features": {"ghcr.io/devcontainers/features/git": {"version": "1.0"}}
        }
        config_path.write_text(json.dumps(config_data))

        result = feature_manager.json_add_feature(
            str(config_path), "ghcr.io/devcontainers/features/git", {"version": "2.0"}
        )

        assert result is True
        config = json.loads(config_path.read_text())
        assert config["features"]["ghcr.io/devcontainers/features/git"] == {
            "version": "2.0"
        }

    def test_add_feature_invalid_json(self, tmp_path, capsys):
        config_path = tmp_path / "devcontainer.json"
        config_path.write_text("not valid json")

        result = feature_manager.json_add_feature(str(config_path), "some-feature")

        assert result is False
        captured = capsys.readouterr()
        assert "Error" in captured.err


class TestSuggestFeatureForAgent:
    @pytest.fixture
    def project_dir_with_config(self, tmp_path):
        devcontainer_dir = tmp_path / ".devcontainer"
        devcontainer_dir.mkdir()
        config_path = devcontainer_dir / "devcontainer.json"
        config_path.write_text(json.dumps({"name": "test"}))
        return tmp_path

    @pytest.fixture
    def feature_mapping_data(self):
        return {
            "opencode": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "aider": (
                "ghcr.io/devcontainers/features/python",
                "For Python/pip dependencies",
            ),
            "copilot-cli": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "cody": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "qwen-cli": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "gemini": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "claude-cli": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "openai-cli": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
        }

    def test_feature_map_for_opencode(self, feature_mapping_data):
        assert feature_mapping_data["opencode"] == (
            "ghcr.io/devcontainers/features/node:1",
            "For Node.js/npm dependencies",
        )

    def test_feature_map_for_aider(self, feature_mapping_data):
        assert feature_mapping_data["aider"] == (
            "ghcr.io/devcontainers/features/python",
            "For Python/pip dependencies",
        )

    def test_feature_map_all_agents(self, feature_mapping_data):
        expected_agents = [
            "opencode",
            "aider",
            "copilot-cli",
            "cody",
            "qwen-cli",
            "gemini",
            "claude-cli",
            "openai-cli",
        ]
        for agent in expected_agents:
            assert agent in feature_mapping_data

    def test_agent_not_found(self, project_dir_with_config, capsys):
        result = feature_manager.suggest_feature_for_agent(
            "nonexistent-agent", str(project_dir_with_config)
        )

        assert result is False
        captured = capsys.readouterr()
        assert "No recommended feature for agent" in captured.out

    def test_no_config_found(self, tmp_path, capsys):
        result = feature_manager.suggest_feature_for_agent("opencode", str(tmp_path))

        assert result is False
        captured = capsys.readouterr()
        assert "No devcontainer configuration found" in captured.out

    def test_feature_already_exists(self, project_dir_with_config, capsys):
        config_path = project_dir_with_config / ".devcontainer" / "devcontainer.json"
        config_data = {"features": {"ghcr.io/devcontainers/features/node:1": {}}}
        config_path.write_text(json.dumps(config_data))

        with patch("builtins.input", return_value=""):
            result = feature_manager.suggest_feature_for_agent(
                "opencode", str(project_dir_with_config)
            )

        assert result is True
        captured = capsys.readouterr()
        assert "already exists" in captured.out

    def test_user_declines_feature(self, project_dir_with_config, capsys):
        with patch("builtins.input", return_value="n"):
            result = feature_manager.suggest_feature_for_agent(
                "opencode", str(project_dir_with_config)
            )

        assert result is False
        captured = capsys.readouterr()
        assert "Skipping automatic feature installation" in captured.out

    def test_user_accepts_feature_with_yes(self, project_dir_with_config, capsys):
        with patch("builtins.input", side_effect=["y", "n"]):
            result = feature_manager.suggest_feature_for_agent(
                "opencode", str(project_dir_with_config)
            )

        assert result is True
        config = json.loads(
            (
                project_dir_with_config / ".devcontainer" / "devcontainer.json"
            ).read_text()
        )
        assert "ghcr.io/devcontainers/features/node:1" in config["features"]

    def test_user_accepts_feature_with_empty_input(
        self, project_dir_with_config, capsys
    ):
        with patch("builtins.input", side_effect=["", "n"]):
            result = feature_manager.suggest_feature_for_agent(
                "aider", str(project_dir_with_config)
            )

        assert result is True
        config = json.loads(
            (
                project_dir_with_config / ".devcontainer" / "devcontainer.json"
            ).read_text()
        )
        assert "ghcr.io/devcontainers/features/python" in config["features"]

    def test_user_accepts_feature_with_yes_full(self, project_dir_with_config, capsys):
        with patch("builtins.input", side_effect=["yes", "n"]):
            result = feature_manager.suggest_feature_for_agent(
                "opencode", str(project_dir_with_config)
            )

        assert result is True

    def test_eof_error_defaults_to_no(self, project_dir_with_config, capsys):
        call_count = 0

        def input_with_eof(*args):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                raise EOFError()
            return "n"

        with patch("builtins.input", side_effect=input_with_eof):
            result = feature_manager.suggest_feature_for_agent(
                "opencode", str(project_dir_with_config)
            )

        assert result is False

    def test_restart_container_success(self, project_dir_with_config, capsys):
        with patch("builtins.input", side_effect=["y", "y"]):
            with patch("subprocess.run") as mock_run:
                mock_run.return_value = MagicMock(returncode=0)
                result = feature_manager.suggest_feature_for_agent(
                    "opencode", str(project_dir_with_config)
                )

        assert result is True
        captured = capsys.readouterr()
        assert "restarted with new feature" in captured.out

    def test_restart_container_failure(self, project_dir_with_config, capsys):
        with patch("builtins.input", side_effect=["y", "y"]):
            with patch("subprocess.run") as mock_run:
                mock_run.return_value = MagicMock(returncode=1, stderr="error")
                result = feature_manager.suggest_feature_for_agent(
                    "opencode", str(project_dir_with_config)
                )

        assert result is True
        captured = capsys.readouterr()
        assert "Failed to restart container" in captured.out

    def test_restart_container_exception(self, project_dir_with_config, capsys):
        with patch("builtins.input", side_effect=["y", "y"]):
            with patch(
                "subprocess.run", side_effect=Exception("command failed")
            ) as mock_run:
                result = feature_manager.suggest_feature_for_agent(
                    "opencode", str(project_dir_with_config)
                )

        assert result is True
        captured = capsys.readouterr()
        assert "Error restarting container" in captured.out


class TestSuggestFeatureForAgentAllAgents:
    @pytest.fixture
    def project_dir_with_config(self, tmp_path):
        devcontainer_dir = tmp_path / ".devcontainer"
        devcontainer_dir.mkdir()
        config_path = devcontainer_dir / "devcontainer.json"
        config_path.write_text(json.dumps({"name": "test"}))
        return tmp_path

    @pytest.fixture
    def feature_mapping_data(self):
        return {
            "opencode": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "aider": (
                "ghcr.io/devcontainers/features/python",
                "For Python/pip dependencies",
            ),
            "copilot-cli": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "cody": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "qwen-cli": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "gemini": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "claude-cli": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
            "openai-cli": (
                "ghcr.io/devcontainers/features/node:1",
                "For Node.js/npm dependencies",
            ),
        }

    @pytest.mark.parametrize(
        "agent",
        [
            "opencode",
            "aider",
            "copilot-cli",
            "cody",
            "qwen-cli",
            "gemini",
            "claude-cli",
            "openai-cli",
        ],
    )
    def test_each_agent_has_mapping(self, agent, feature_mapping_data):
        assert agent in feature_mapping_data

    @pytest.mark.parametrize(
        "agent",
        [
            "opencode",
            "copilot-cli",
            "cody",
            "qwen-cli",
            "gemini",
            "claude-cli",
            "openai-cli",
        ],
    )
    def test_node_feature_for_non_aider_agents(
        self, project_dir_with_config, agent, capsys
    ):
        with patch("builtins.input", side_effect=["y", "n"]):
            result = feature_manager.suggest_feature_for_agent(
                agent, str(project_dir_with_config)
            )

        assert result is True
        config = json.loads(
            (
                project_dir_with_config / ".devcontainer" / "devcontainer.json"
            ).read_text()
        )
        assert "ghcr.io/devcontainers/features/node:1" in config["features"]


class TestMain:
    def test_main_insufficient_args(self, capsys):
        with patch.object(sys, "argv", ["feature_manager.py"]):
            with pytest.raises(SystemExit) as exc_info:
                feature_manager.main()

        assert exc_info.value.code == 1
        captured = capsys.readouterr()
        assert "Usage:" in captured.err

    def test_main_with_args(self, tmp_path, capsys):
        devcontainer_dir = tmp_path / ".devcontainer"
        devcontainer_dir.mkdir()
        config_path = devcontainer_dir / "devcontainer.json"
        config_path.write_text(json.dumps({"name": "test"}))

        with patch("builtins.input", return_value="n"):
            with patch.object(
                sys,
                "argv",
                ["feature_manager.py", "opencode", str(tmp_path)],
            ):
                with pytest.raises(SystemExit):
                    feature_manager.main()


class TestIntegration:
    def test_full_workflow_add_feature_to_devcontainer(self, tmp_path):
        devcontainer_dir = tmp_path / ".devcontainer"
        devcontainer_dir.mkdir()
        config_path = devcontainer_dir / "devcontainer.json"
        config_path.write_text(
            json.dumps({"name": "test", "containerUser": "developer"})
        )

        config_path_str = str(config_path)
        assert (
            feature_manager.feature_exists_in_devcontainer(
                config_path_str, "ghcr.io/devcontainers/features/git"
            )
            is False
        )
        assert (
            feature_manager.json_add_feature(
                config_path_str,
                "ghcr.io/devcontainers/features/git",
                {"version": "1.0"},
            )
            is True
        )
        assert (
            feature_manager.feature_exists_in_devcontainer(
                config_path_str, "ghcr.io/devcontainers/features/git"
            )
            is True
        )

        config = json.loads(config_path.read_text())
        assert "ghcr.io/devcontainers/features/git" in config["features"]

    def test_get_config_path_and_check_feature(self, tmp_path):
        devcontainer_dir = tmp_path / ".devcontainer"
        devcontainer_dir.mkdir()
        config_path = devcontainer_dir / "devcontainer.json"
        config_data = {"name": "test", "features": {"existing-feature": {}}}
        config_path.write_text(json.dumps(config_data))

        found_path = feature_manager.get_devcontainer_config_path(str(tmp_path))
        assert found_path is not None

        exists = feature_manager.feature_exists_in_devcontainer(
            found_path, "existing-feature"
        )
        assert exists is True

        exists_new = feature_manager.feature_exists_in_devcontainer(
            found_path, "nonexistent-feature"
        )
        assert exists_new is False
