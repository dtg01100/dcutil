import pytest
from lib import feature_cli


class TestCanonicalizeSpec:
    """Tests for the canonicalize_spec function."""

    def test_empty_string_returns_empty(self):
        result = feature_cli.canonicalize_spec("")
        assert result == ""

    def test_empty_string_with_whitespace_returns_empty(self):
        result = feature_cli.canonicalize_spec("   ")
        assert result == ""

    def test_short_name_git(self):
        result = feature_cli.canonicalize_spec("git")
        assert result == "ghcr.io/devcontainers/features/git"

    def test_short_name_docker(self):
        result = feature_cli.canonicalize_spec("docker")
        assert result == "ghcr.io/devcontainers/features/docker"

    def test_short_name_node(self):
        result = feature_cli.canonicalize_spec("node")
        assert result == "ghcr.io/devcontainers/features/node"

    def test_medium_name_devcontainers_features_git(self):
        result = feature_cli.canonicalize_spec("devcontainers/features/git")
        assert result == "devcontainers/features/git"

    def test_medium_name_with_different_namespace(self):
        result = feature_cli.canonicalize_spec("custom/features/git")
        assert result == "custom/features/git"

    def test_full_name_ghcr_io_devcontainers_features_git(self):
        result = feature_cli.canonicalize_spec("ghcr.io/devcontainers/features/git")
        assert result == "ghcr.io/devcontainers/features/git"

    def test_full_name_with_different_registry(self):
        result = feature_cli.canonicalize_spec("ghcr.io/myorg/features/git")
        assert result == "ghcr.io/myorg/features/git"

    def test_short_name_with_version(self):
        result = feature_cli.canonicalize_spec("git:1")
        assert result == "ghcr.io/devcontainers/features/git:1"

    def test_short_name_with_major_minor_version(self):
        result = feature_cli.canonicalize_spec("git:1.2")
        assert result == "ghcr.io/devcontainers/features/git:1.2"

    def test_short_name_with_full_semver_version(self):
        result = feature_cli.canonicalize_spec("git:1.2.3")
        assert result == "ghcr.io/devcontainers/features/git:1.2.3"

    def test_full_name_with_version_preserved(self):
        result = feature_cli.canonicalize_spec("ghcr.io/devcontainers/features/git:1")
        assert result == "ghcr.io/devcontainers/features/git:1"

    def test_medium_name_with_version_preserved(self):
        result = feature_cli.canonicalize_spec("devcontainers/features/git:2")
        assert result == "devcontainers/features/git:2"

    def test_whitespace_stripped_from_short_name(self):
        result = feature_cli.canonicalize_spec("  git  ")
        assert result == "ghcr.io/devcontainers/features/git"

    def test_whitespace_stripped_from_full_name(self):
        result = feature_cli.canonicalize_spec("  ghcr.io/devcontainers/features/git  ")
        assert result == "ghcr.io/devcontainers/features/git"

    def test_whitespace_stripped_from_name_with_version(self):
        result = feature_cli.canonicalize_spec("  git:1  ")
        assert result == "ghcr.io/devcontainers/features/git:1"

    def test_custom_registry_with_slash(self):
        result = feature_cli.canonicalize_spec("myregistry.io/features/git")
        assert result == "myregistry.io/features/git"

    def test_custom_registry_with_path(self):
        result = feature_cli.canonicalize_spec(
            "registry.example.com/containers/features/git"
        )
        assert result == "registry.example.com/containers/features/git"

    def test_short_name_with_dashes(self):
        result = feature_cli.canonicalize_spec("docker-in-docker")
        assert result == "ghcr.io/devcontainers/features/docker-in-docker"

    def test_short_name_with_underscores(self):
        result = feature_cli.canonicalize_spec("java_sdk")
        assert result == "ghcr.io/devcontainers/features/java_sdk"

    def test_short_name_with_numbers(self):
        result = feature_cli.canonicalize_spec("python3")
        assert result == "ghcr.io/devcontainers/features/python3"

    def test_multiple_features_separate_calls(self):
        result1 = feature_cli.canonicalize_spec("git")
        result2 = feature_cli.canonicalize_spec("docker")
        result3 = feature_cli.canonicalize_spec("node")
        assert result1 == "ghcr.io/devcontainers/features/git"
        assert result2 == "ghcr.io/devcontainers/features/docker"
        assert result3 == "ghcr.io/devcontainers/features/node"

    def test_isolated_calls_do_not_affect_each_other(self):
        result1 = feature_cli.canonicalize_spec("git:1")
        result2 = feature_cli.canonicalize_spec("git")
        result3 = feature_cli.canonicalize_spec("git:2")
        assert result1 == "ghcr.io/devcontainers/features/git:1"
        assert result2 == "ghcr.io/devcontainers/features/git"
        assert result3 == "ghcr.io/devcontainers/features/git:2"
