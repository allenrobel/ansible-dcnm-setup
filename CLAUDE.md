# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository exists to simplify setup of the Cisco DCNM Ansible Collection using `uv` instead of `pip` for dependency management. It contains a setup script that installs the DCNM Ansible Collection and uses `uv` to install its dependencies.

## Architecture Overview

### Two-Repository Structure

This repository manages setup for a **separate** target repository:

1. **This repository** (`ansible-dcnm-setup`): Contains setup scripts and configuration files
2. **Target repository** (`$HOME/repos/ansible/collections/ansible_collections/cisco/dcnm`): The actual DCNM Ansible Collection where development happens

### Key Files and Their Destinations

- `dcnm/pyproject.toml` -> Copied to DCNM Collection repository
  - Contains dependencies (ansible, requests, pydantic, etc.)
  - Includes tool configurations for black, isort, mypy, pylint, pyright
  - Defines three dependency groups: base runtime, test, and dev
- `dcnm/env` -> Copied to DCNM Collection repository as `env/env`
  - Sets environment variables for Ansible paths and Python paths
- `pyproject.toml` (root) -> Local use only for this setup repository

### Installation Flow

The `setup_dcnm_repo.bash` script performs these steps:

1. Checks that no virtual environment is active (exits if one is)
2. Creates directory structure at `$HOME/repos/ansible/collections/ansible_collections/`
3. Clones `ansible.netcommon` collection from ansible-collections/ansible.netcommon
4. Clones `ansible-dcnm` from CiscoDevNet/ansible-dcnm
5. Copies `dcnm/pyproject.toml` and `dcnm/env` to the cloned DCNM repository
6. Installs `uv` via curl script from astral.sh
7. Installs Python 3.11 via `uv`
8. Creates virtual environment in DCNM repository with `uv venv --python 3.11 --prompt dcnm`
9. Installs only base dependencies with `uv sync --no-group dev --no-group test`

## Development Commands

All development work happens in the **target DCNM repository**, not this one.

### Activating the Environment

```bash
cd $HOME/repos/ansible/collections/ansible_collections/cisco/dcnm
source .venv/bin/activate
source env/env
```

### Installing Additional Dependencies

By default, only base runtime dependencies are installed. Install additional groups as needed:

```bash
# For running pytest and pytest --cov
uv sync --group test

# For running linters (mypy, black, isort, pylint, yamllint, etc.)
uv sync --group dev

# Install everything
uv sync --all-groups
# OR
uv sync --group dev --group test
```

### Running Tests

```bash
cd $HOME/repos/ansible/collections/ansible_collections/cisco/dcnm
source .venv/bin/activate
source env/env
cd tests/unit/modules/dcnm
pytest -k <module_name>  # e.g., pytest -k dcnm_fabric
```

### Code Quality Tools

The DCNM repository uses these linters (configured in `dcnm/pyproject.toml`):

- **black**: Code formatter (line-length: 160)
- **isort**: Import sorter (profile: black, line_length: 160)
- **mypy**: Static type checker (with pydantic plugin)
- **pylint**: Code analyzer (Python 3.11, max-line-length: 160)
- **pyright**: Type checker (basic mode, Python 3.11)
- **yamllint**: YAML linter
- **mdformat**: Markdown formatter (wrap: 160)

## Environment Variables

When `env/env` is sourced in the DCNM repository:

- `PYTHON_VERSION=3.11`
- `ANSIBLE_HOME=$HOME/repos/ansible`
- `ANSIBLE_COLLECTIONS_PATH=$ANSIBLE_HOME/collections`
- `ANSIBLE_ROLES_PATH=$ANSIBLE_COLLECTIONS_PATH/ansible_collections/cisco/dcnm/tests/integration/targets`
- `ANSIBLE_LIBRARY=$ANSIBLE_COLLECTIONS_PATH/ansible_collections/cisco/dcnm/.venv/lib/python$PYTHON_VERSION/site-packages/ansible_collections`
- `PYTHONPATH=.:$ANSIBLE_COLLECTIONS_PATH`

## Important Notes

- The setup script requires NO virtual environment to be active before running
- Python 3.11 is the currently-recommended version for the DCNM Collection
- uv installs files in `$HOME/.local/bin/` (uv, uvx, python3.11, env, env.fish)
- The DCNM Ansible Collection is for Cisco Nexus Dashboard Fabric Controller (NDFC), formerly known as Cisco Data Center Network Manager (DCNM)
- This repository automates VXLAN EVPN fabric day-2 operations
