# Tech Context

**Languages:** Primarily Bash; some Python utilities (`feature_manager.py`, `json_utils.py`).

**Key Dependencies:**
- Official Devcontainer CLI (`@devcontainers/cli`) for primary container operations.
- Docker or Podman runtimes, auto-detected.
- `jq`, `curl`, `dialog` (optional for UI), `sed`, `awk`, `tar`, `python3`.

**Environment:** Linux/macOS shells; scripts assume POSIX/Bash. Completion scripts for bash/zsh/fish. Homebrew tap available for Linux.

**Structure:**
- Root scripts: `dcutil`, `dcutil.rb`, completion scripts, test runners.
- Libraries under `lib/` plus mirrored packaged files under `dcutil-files/lib/` (release artifacts).
- Tests under `test_*/`, `test-*/`, `.expect` files for expect harness.

**Constraints:**
- Must remain portable between Docker and Podman; prefer devcontainer CLI as source of truth.
- Clear exit codes (0-6) mapping to failure classes.
- Aim for beginner-friendly output and guidance.
