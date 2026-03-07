# System Patterns

- **Modular Bash architecture:** core utilities in `lib/core.sh` with feature-specific modules (volumes, compose, environment, integration, hostrequirements, etc.).
- **Backend abstraction:** Uses official `devcontainer` CLI for spec-compliant actions; falls back to Docker/Podman scripts for gaps (restart/status/logs/list). Backend detection cached via `DETECTED_BACKEND` after `devcontainer up`.
- **CLI entrypoint:** `./dcutil` (and mirrored in `dcutil-files/dcutil`) dispatches to subcommands sourced from `lib/` modules.
- **UX helpers:** `lib/ux.sh` for prompts/menu, dialog UI when available with text fallback; completion scripts provided.
- **Testing:** expect scripts and shell test runners (`test.sh`, `run_expect_tests.sh`, targeted suites) for regression coverage; test data under `testdata/` and `testfeature/`.
- **Python utilities:** `feature_manager.py` and `json_utils.py` support feature operations/JSON handling where Bash is cumbersome.
- **Configuration caching:** Some operations write temp or cache files (e.g., template/feature catalogs) respecting 24h TTL.
