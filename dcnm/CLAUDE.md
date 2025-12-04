# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in the ansible-dcnm repository.

## Overview

This repository contains the Cisco DCNM (Data Center Network Manager) / NDFC (Nexus Dashboard Fabric Controller) Ansible collection. It provides modules to automate day-2 operations for VXLAN EVPN fabrics.

## Common Commands

### Linting and Code Quality

```bash
# Run all linters (black, isort, pylint, mypy)
tox -e linters

# Run black formatter only
tox -e black

# Run a specific linter on a file
isort <file>
black -v -l160 <file>

# Run pylint (if configured)
pylint <file>

# Run markdown linter
markdownlint <file>.md
```

**IMPORTANT: Markdown Files**

All markdown files (*.md) MUST pass the markdown linter without errors. Common violations to avoid:

- **MD031**: Fenced code blocks should be surrounded by blank lines
- **MD032**: Lists should be surrounded by blank lines
- **MD022**: Headings should be surrounded by blank lines

Example of correct markdown formatting:

```markdown
Some text before.

# Heading

Content after heading.

- List item 1
- List item 2

Text after list.

‍```bash
code block
‍```

Text after code block.

## Subheading

Content after subheading.
```

### Testing

```bash
# Run unit tests
python -m pytest tests/unit/

# Run unit tests with coverage
coverage run -m pytest tests/unit/ && coverage report

# Run integration tests
ansible-test integration

# Run sanity tests
ansible-test sanity --docker

# Run specific test file
python -m pytest tests/unit/path/to/test_file.py

# Run tests with parallel execution
python -m pytest tests/unit/ -n auto
```

### Development Environment

#### Enable virtual environment

```bash
source .venv/bin/activate
```

#### Set repository-specific env vars

```bash
source env/env
```

#### Install dependencies

```bash
pip install -r requirements.txt -r test-requirements.txt
```

#### Run in development mode

```bash
tox -e venv -- <command>
```

#### Install collection in development mode

```bash
ansible-galaxy collection install . --force
```

## Architecture

### Directory Structure

- `plugins/modules/` - Ansible modules (dcnm_vrf, dcnm_fabric, dcnm_interface, etc.)
- `plugins/module_utils/` - Shared utility modules organized by feature
- `plugins/httpapi/` - HTTP API plugin for DCNM/NDFC communication
- `plugins/action/` - Action plugins for complex module operations
- `tests/unit/` - Unit tests mirroring the plugins directory structure
- `tests/integration/` - Integration tests with real DCNM/NDFC instances

### Key Modules

#### Core Infrastructure Modules

- **dcnm_fabric** - Fabric creation and management
- **dcnm_inventory** - Switch inventory management
- **dcnm_links** - Inter-switch link management

#### Network Configuration Modules

- **dcnm_vrf** - VRF management (active development with Pydantic models)
- **dcnm_network** - Network/VLAN management
- **dcnm_interface** - Interface configuration
- **dcnm_policy** - Policy management

#### Image and Maintenance Modules

- **dcnm_image_policy** - Image policy management
- **dcnm_image_upgrade** - Switch image upgrades
- **dcnm_image_upload** - Image upload to DCNM/NDFC
- **dcnm_maintenance_mode** - Maintenance mode operations

#### Utility Modules

- **dcnm_rest** - Generic REST API operations
- **dcnm_log** - Logging operations
- **dcnm_template** - Template management

### Key Components

#### Module Utils Architecture

- `plugins/module_utils/common/` - Shared utilities (API clients, logging, validation)
- `plugins/module_utils/vrf/` - VRF-specific utilities and models
- `plugins/module_utils/fabric/` - Fabric management utilities
- `plugins/module_utils/image_*` - Image/software management utilities

#### API Layer

- `plugins/module_utils/common/api/` - Hierarchical API structure matching DCNM/NDFC REST endpoints
- `plugins/module_utils/common/rest_send*.py` - HTTP request handling
- `plugins/module_utils/common/sender_*.py` - Request sender implementations

#### VRF Module (Active Development)

The VRF module is currently being refactored to use Pydantic models:

- `plugins/module_utils/vrf/dcnm_vrf_v12.py` - Main VRF module (v12 API)
- `plugins/module_utils/vrf/model_*.py` - Pydantic models for request/response data
- Working on integrating Pydantic validation throughout the VRF workflow

**IMPORTANT**: `plugins/module_utils/vrf/dcnm_vrf_v11.py` is dead code and should NOT be used as reference for current work. All active development should focus on the v12 implementation.

### Design Patterns

#### State Management

Modules follow Ansible's declarative state patterns:

- `merged` - Add/update resources
- `replaced` - Replace specific resources
- `overridden` - Replace all resources
- `deleted` - Remove resources
- `query` - Retrieve current state

**Reference**: Ansible state patterns are defined in module implementations. See existing modules for examples of how these states are handled.

**HTTP Methods**: Currently HTTP methods are used as string literals ("GET", "POST", "PUT", "DELETE") throughout the codebase. A `RequestVerb` enum is being developed but not yet implemented.

#### Data Validation

- Transitioning from manual validation to Pydantic models
- Models define request/response schemas with validation
- Located in `model_*.py` files within each feature directory

#### Error Handling

- Consistent error handling through `common/exceptions.py`
- Response validation and error reporting
- Rollback capabilities for failed operations

## Development Guidelines

### Code Standards

- Line length: 160 characters (configured in tox.ini and pylintrc)
- Imports sorted to conform with isort linter
- Black formatting enforced (black==24.3.0)
- Type hints encouraged (mypy configuration in mypy.ini)
- Pydantic models for data validation (preferred for new code, version 2.11.4)
- pylint configuration available (pylintrc) with snake_case naming conventions
- Class and method docstrings conform to Markdown and should pass the mdformat linter

#### Class and method docstrings

All class and method docstrings MUST use proper Markdown formatting:

- Use `# Summary` as the top-level heading (starts with single `#`)
- A `## Raises` heading MUST be included and must contain
  - None, if the class or method does not raise an exception
  - Subheadings (e.g. ### ValueError) for each exception type that is raised by the method or class.
    - Each subheading must contain a Markdown list of conditions under which the exception type is raised.
- Use `## Raises`, `## Notes`, etc. as second-level headings (start with `##`)
- Ensure blank lines surround headings per markdown linting rules
- **IMPORTANT**: Use single backticks (`` ` ``) for inline code references, NOT double backticks (` `` `)
  - Variables: `value`, `config`, `params`
  - Methods: `commit()`, `refresh()`, `get_want()`
  - Classes: `ValueError`, `TypeError`, `MaintenanceMode()`
  - Properties: `rest_send`, `fabric_name`, `serial_number`
  - Exception names: `ValueError`, `TypeError`, `AttributeError`

**Example:**

```python
def some_method(self, value: str) -> None:
    """
    # Summary

    Do something with the provided value.

    ## Raises

    - `ValueError` if value is empty or None
    - `TypeError` if value is not a string

    ## Notes

    This method modifies internal state.
    """
```

### Testing Requirements

- Unit tests required for all new functionality
- Integration tests for complex workflows
- Fixtures in `tests/unit/*/fixtures/` directories
- Mock responses for controller interactions

#### Unit Test Structure and Patterns

**Test Organization:**

- Unit tests mirror the structure of `plugins/module_utils/`
- Test files are named `test_<module_name>.py`
- Fixtures are stored in `tests/unit/*/fixtures/*.json`
- Each test class tests a specific module utility class

**Standard Pylint Directives for Unit Tests:**

All unit test files should include these pylint disable directives at the top (after the license header and before the module docstring):

```python
# pylint: disable=unused-import
# pylint: disable=redefined-outer-name
# pylint: disable=protected-access
# pylint: disable=unused-argument
# pylint: disable=unused-variable
# pylint: disable=invalid-name
# pylint: disable=line-too-long
# pylint: disable=too-many-lines
```

These directives are necessary because:

- `unused-import` - Fixtures imported but used via pytest's dependency injection
- `redefined-outer-name` - Fixture functions redefine names from outer scope
- `protected-access` - Tests need to access private methods/attributes (e.g., `_get`, `_refreshed`)
- `unused-argument` - Fixture parameters may not be directly used in function body
- `unused-variable` - Variables assigned but not used when testing property access
- `invalid-name` - Test function names may not follow standard naming conventions
- `line-too-long` - Some test assertions require long lines
- `too-many-lines` - Comprehensive test files may exceed line limits

**Fixture Naming Convention:**

- Each test should have its own unique fixture data to avoid test coupling
- Use the pattern: `test_<module>_<test_number>a` (e.g., `test_fabric_group_details_00040a`)
- The `a` suffix is appended to the test method name via: `key = f"{inspect.stack()[0][3]}a"`
- **CRITICAL**: Never reuse fixture data across tests unless explicitly testing shared/common scenarios

**Response Generator Pattern:**

```python
method_name = inspect.stack()[0][3]  # Gets test method name
key = f"{method_name}a"              # Creates unique fixture key

def responses():
    # Each yield corresponds to a REST API call in the test
    yield responses_fabric_groups(f"{key}")         # From responses_FabricGroups.json
    yield responses_fabric_group_details(f"{key}") # From responses_FabricGroupDetails.json

gen_responses = ResponseGenerator(responses())
```

**Mock Setup Pattern:**

```python
sender = Sender()
sender.ansible_module = MockAnsibleModule()
sender.gen = gen_responses

rest_send = RestSend(params)
rest_send.unit_test = True
rest_send.timeout = 1
rest_send.response_handler = ResponseHandler()
rest_send.sender = sender
```

**Common Test Patterns:**

1. **Initialization Tests** (`test_*_00000`):
   - Verify class attributes are initialized correctly
   - Check default values
   - Ensure no exceptions during instantiation

2. **Property Tests** (`test_*_000XX`):
   - Test property setters and getters
   - Verify ValueError when accessing properties before setting required dependencies
   - Test property validation

3. **Method Tests** (`test_*_001XX`):
   - Test core functionality with valid inputs
   - Test error conditions and exception handling
   - Verify state changes and side effects

4. **Assertion Patterns:**

   - Use `does_not_raise()` context manager for expected success cases
   - Use `pytest.raises(ValueError, match=r"...")` for expected exceptions
   - For `Results.changed`, use `assert False in instance.results.changed` (not `is False`)
   - **IMPORTANT**: Never use `_` as a variable name in tests (causes pylint disallowed-name error)
   - Use descriptive variable names like `result` even if the value is unused:

     ```python
     # CORRECT - use descriptive variable name
     with pytest.raises(ValueError, match=match):
         result = instance.some_property  # pylint: disable=pointless-statement

     # INCORRECT - causes pylint disallowed-name error
     with pytest.raises(ValueError, match=match):
         _ = instance.some_property  # pylint: disable=pointless-statement
     ```

**Fixture File Structure:**

Each fixture JSON file should contain:

```json
{
    "TEST_NOTES": [
        "Description of the fixture file",
        "Which test files use it",
        "Instructions for gathering/updating responses"
    ],
    "test_module_name_00040a": {
        "TEST_NOTES": ["Specific notes for this test"],
        "RETURN_CODE": 200,
        "METHOD": "GET",
        "REQUEST_PATH": "/api/endpoint",
        "MESSAGE": "OK",
        "DATA": { /* response data */ }
    }
}
```

**Multiple Fixture Files:**

- Some tests require responses from multiple fixture files (e.g., `responses_FabricGroups.json` AND `responses_FabricGroupDetails.json`)
- Each fixture file must have a matching entry for the test's unique key
- Order of `yield` statements must match the order of API calls in the code being tested

**Docstring Formatting:**

All test function docstrings MUST use proper Markdown formatting:

- Use `# Summary` as the top-level heading (starts with single `#`)
- Use `## Classes and Methods`, `## Test`, etc. as second-level headings (start with `##`)
- `## Classes and Methods` should be the last section in each docstring
- Ensure blank lines surround headings per markdown linting rules
- Follow markdown linting rules (MD022, MD031, MD032)

**Example Test Structure:**

```python
def test_fabric_group_details_00040(fabric_group_details) -> None:
    """
    # Summary

    Verify behavior when refresh() is called and fabric group exists

    ## Test

    - fabric_group_name is set to "MFG1"
    - refresh() populates data correctly
    - Data contains expected fields

    ## Classes and Methods

    - FabricGroupDetails.__init__()
    - FabricGroupDetails.refresh()
    """
    method_name = inspect.stack()[0][3]
    key = f"{method_name}a"

    def responses():
        yield responses_fabric_groups(f"{key}")
        yield responses_fabric_group_details(f"{key}")

    gen_responses = ResponseGenerator(responses())

    # Setup mocks (sender, rest_send, etc.)

    with does_not_raise():
        instance = fabric_group_details
        instance.rest_send = rest_send
        instance.results = Results()
        instance.fabric_group_name = "MFG1"
        instance.refresh()

    # Assertions
    assert instance._refreshed is True
    assert instance.data.get("MFG1") is not None
    assert instance.data["MFG1"]["fabricName"] == "MFG1"
```

**Test Isolation Best Practices:**

- Each test must have completely unique fixture data
- Changing one test's fixture should never break another test
- Only share fixtures for truly common scenarios (e.g., empty responses, error responses)
- Document when and why fixtures are shared using TEST_NOTES

### Common Patterns

- Use `plugins/module_utils/common/rest_send_v2.py` for HTTP requests
- Use string literals for HTTP methods until `RequestVerb` enum is implemented ("GET", "POST", "PUT", "DELETE")
- Implement proper logging using `plugins/module_utils/common/log_v2.py`
- Follow existing module structure in `plugins/modules/`
- Use dataclasses or Pydantic models for structured data (preferred for new development)

### Version Compatibility

- Support DCNM 11.4(1)+ and NDFC 12.0+
- Ansible 2.15.0+ compatibility required
- Python 3.x support

## Notes for AI Development

### Current Focus Areas

- VRF module Pydantic integration is in progress
- Pay attention to `plugins/module_utils/vrf/` for latest patterns
- Follow the model-based validation approach being implemented
- **AVOID**: Do not reference or modify `dcnm_vrf_v11.py` - it is dead code

### Testing Strategy

- Always run `tox -e linters` before committing
- Unit tests should mock controller responses using fixtures
- Integration tests require real DCNM/NDFC instances

### Common Issues

- Long query strings in URLs may need special handling (see `vrf_utils.py`)
- Controller API versioning differences between DCNM/NDFC
- Pydantic validation errors need proper error message formatting

## Code Memory

### Module Utility Conventions

- HTTP methods are currently used as string literals ("GET", "POST", "PUT", "DELETE") throughout the codebase
- The `RequestVerb` enum is in development but not yet implemented in the common/enums directory
- Pydantic models are being actively developed for VRF module validation (see `plugins/module_utils/vrf/model_*.py`)

### Collection Information

- **Namespace**: `cisco.dcnm`
- **Current Version**: 3.8.1-dev
- **Repository**: https://github.com/CiscoDevNet/ansible-dcnm
- **Main Development Branch**: `develop`

### Linting and Formatting

- The following linters should always be run when verifying new code, or changes to existing code
  - black -l160
  - isort
  - pylint
  - mypy
