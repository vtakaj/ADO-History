# ADO-History

A tool that extracts ticket history from Azure DevOps.

## Configuration

Configure the connection before using Azure DevOps Tracker.

### Security (API key)

If you accidentally commit an API key, revoke/rotate it immediately.

Minimum response steps:
1. Revoke/rotate the key in the OpenAI dashboard
2. Remove the plain text key from the repository (delete or replace the file)
3. If already pushed, remove it from history as well (BFG/filter)
4. Create a new key and manage it via environment variables (such as `OPENAI_API_KEY`)

If a leak is suspected, treat it as high priority.

### Generate configuration template

```bash
# Generate a configuration template
./ado-tracker.sh config template

# Copy .env.template to .env and edit
cp .env.template .env
# Set required values in .env

# Show configuration
./ado-tracker.sh config show

# Validate configuration
./ado-tracker.sh config validate
```

### Codex authentication

Codex CLI and the VS Code extension authenticate using one of the following methods.

1) ChatGPT sign-in (recommended)
- Run `codex --login` to sign in
- Credentials are saved in the user directory (for devcontainer, mount `~/.codex`)

2) API key
- Set the `OPENAI_API_KEY` environment variable
- When using a devcontainer, it is convenient to pass host environment variables via `remoteEnv` in `devcontainer.json`

```json
"remoteEnv": {
  "OPENAI_API_KEY": "${localEnv:OPENAI_API_KEY}"
}
```

### Environment variables

The following environment variables are required:

#### Required
- `AZURE_DEVOPS_PAT`: Personal Access Token (required)
- `AZURE_DEVOPS_ORG`: Organization name (required)
- `AZURE_DEVOPS_PROJECT`: Default project name (used by the fetch command)

#### Optional
- `API_VERSION`: Azure DevOps API version (default: 7.2)
- `LOG_LEVEL`: log level - INFO|WARN|ERROR (default: INFO)
- `RETRY_COUNT`: API retry count (default: 3)
- `RETRY_DELAY`: retry interval in seconds (default: 1)
- `REQUEST_TIMEOUT`: API request timeout in seconds (default: 30)
- `BATCH_SIZE`: batch size (default: 50)

## Error handling and logging (US-001-BE-005)

### Enhanced error handling

Provide detailed guidance for errors when calling the Azure DevOps API:

- **401 Auth error**: suggest checking PAT expiry, permissions, and org name
- **403 Permission error**: suggest checking PAT scopes and project membership
- **404 Resource error**: suggest checking project name, org name, and Work Item ID
- **429 Rate limit**: parse the Retry-After header and set an appropriate wait time
- **5xx Server error**: suggest checking Azure DevOps service status and retrying
- **Network error**: suggest checking connectivity, proxy settings, and timeouts

### Exponential backoff retry

- Start from the initial delay and double it on each failure
- Continue until the max delay (300 seconds) is reached
- For rate limits, prefer the Retry-After header

### Checkpoint recovery

Recovery after interruption:

```bash
# After interruption, rerun the same command for automatic recovery
./ado-tracker.sh fetch MyProject 30

# Checkpoint file location
./data/checkpoint.json
```

### Timestamped logs

All log messages include timestamps:

```
[2025-07-25 01:30:00] [INFO] API request: GET https://dev.azure.com/org/project/_apis/wit/workitems
[2025-07-25 01:30:01] [WARN] Rate limit: retry in 60 seconds (HTTP 429)
[2025-07-25 01:30:02] [ERROR] Auth error: please check your PAT
```

## Basic usage

```bash
# Show help
./ado-tracker.sh help

# API connection test
./ado-tracker.sh test-connection   # Azure DevOps API connection test

# Configuration
./ado-tracker.sh config show      # Show configuration
./ado-tracker.sh config validate  # Validate configuration
./ado-tracker.sh config template  # Generate template

# Fetch ticket history (uses default project in AZURE_DEVOPS_PROJECT)
./ado-tracker.sh fetch 30                 # Fetch last 30 days for default project

# Fetch with details (default project)
./ado-tracker.sh fetch 30 --with-details  # Fetch with additional details

# Fetch only status history
./ado-tracker.sh status-history ProjectName  # Fetch status history for existing Work Items
./ado-tracker.sh status-history              # Fetch using the default project

# Fetch only Work Item details
./ado-tracker.sh fetch-details ProjectName  # Fetch details for existing Work Items
./ado-tracker.sh fetch-details              # Fetch using the default project

# Generate work record table (markdown)
./ado-tracker.sh generate-work-table 2025-01 ./work_records/2025-01.md  # Monthly work table
```

## Tests

```bash
# Integration tests
./tests/integration/test_main.sh
./tests/integration/test_work_table.sh
./tests/integration/test_error_scenarios.sh
./tests/integration/test_fetch_flow.sh

# Unit tests
./tests/unit/test_api.sh
./tests/unit/test_config.sh
./tests/unit/test_data.sh
./tests/unit/test_output.sh
```

Tests use a mock API, so a live Azure DevOps connection is not required.

## Feature details

### Work Items fetch (fetch)

Fetch Work Items (tickets) and status history for the specified project, and save them locally as JSON.

#### Basic behavior
The standard fetch command retrieves the following:
- **Basic info**: ticket ID, title, assignee, current status, last updated time
- **Status history**: status change history for each ticket

#### Details option
With the `--with-details` option, additional details are fetched:
- **Details**: ticket type, priority, created time, estimated time, description, etc.

#### Data storage
- Basic info: `./data/workitems.json`
- Status history: `./data/status_history.json`
- Details: `./data/workitem_details.json` (only when using `--with-details`)
- Existing data is backed up automatically under `./data/backup/`
- Supports pagination to handle large datasets

#### Examples
```bash
# Fetch basic data for the last 30 days in the default project
./ado-tracker.sh fetch 30

# Fetch with additional details
./ado-tracker.sh fetch 30 --with-details

# Fetch basic data for the last 7 days
./ado-tracker.sh fetch 7
```

### Status history (status-history)

Fetch status change history for each Work Item and record it in JST.

#### Data collected
- Work Item ID
- Change time (JST)
- Changed by
- Status before change
- Status after change
- Revision number

#### Data storage
- Saved to `./data/status_history.json`
- Existing data is backed up automatically under `./data/backup/`
- Sorted by change time

#### Examples
```bash
# Fetch status history for the default project
./ado-tracker.sh status-history

# The fetch command also retrieves status history automatically
./ado-tracker.sh fetch 30
```

### Work Item details (fetch-details)

Fetch details for each Work Item and record them in JST. This requires existing `workitems.json`.

#### Data collected
- Work Item ID
- Ticket title
- Ticket type (User Story, Bug, Task, etc.)
- Priority
- Created time (JST)
- Last updated time (JST)
- Original estimate
- Assignee
- Current status
- Description (optional)

#### Data storage
- Saved to `./data/workitem_details.json`
- Existing data is backed up automatically under `./data/backup/`
- Fast retrieval via batch processing

#### Examples
```bash
# Fetch Work Item details for the default project
./ado-tracker.sh fetch-details

# Use --with-details on fetch to include details
./ado-tracker.sh fetch 30 --with-details
```

### Generate work table (generate-work-table)

Generate a markdown work record table from fetched ticket data and status history.

#### Features

- **Monthly table**: daily work record table for the specified month
- **Assignee columns**: auto-detect assignees from status history and create columns
- **Ticket ID display**: show ticket IDs during Doing to Done window
- **Blocked handling**: hide while Blocked (hidden the next day, reappears when unblocked)
- **Manual entry**: work time is entered manually later (h:mm)
- **Monthly totals**: footer includes monthly total time
- **Ticket list**: list of ticket IDs and titles for the month

#### Output format

```markdown
# Work Record Table (2025-01)

| Date | Day | Taro Tanaka | Work | Hanako Sato | Work |
|------|-----|------------|------|------------|------|
| 2025/01/10 | Fri | | 12345 | | |
| 2025/01/12 | Sun | | | | 12346 |
| **Total** | | **--:--** | | **--:--** | |

## Ticket List (January 2025)

- **12345**: Implement user authentication feature
- **12346**: Fix login validation bug
```

#### Examples

```bash
# Generate the work record table for January 2025
./ado-tracker.sh generate-work-table 2025-01 ./work_records/2025-01.md

# Generate the work record table for February 2025
./ado-tracker.sh generate-work-table 2025-02 ./work_records/2025-02.md
```

## Project structure

Organized project structure after refactoring:

```
ado-history/
├── ado-tracker.sh          # Main script (lightweight: 106 lines)
├── lib/                    # Module library
│   ├── core/              # Core functions
│   │   ├── api_client.sh  # Azure DevOps API client
│   │   ├── config_manager.sh # Configuration management
│   │   ├── data_processor.sh # Data processing and transformation
│   │   └── logger.sh      # Logging
│   ├── commands/          # Command implementations
│   │   ├── fetch.sh       # fetch command implementation
│   │   ├── generate_table.sh # Table generation implementation
│   │   └── test_connection.sh # Connection test implementation
│   ├── formatters/        # Output formatting
│   │   ├── markdown.sh    # Markdown output
│   │   └── display.sh     # Display/UI
│   └── utils/             # Utilities
│       ├── date_utils.sh  # Date handling
│       ├── string_utils.sh # String handling
│       ├── file_utils.sh  # File handling
│       └── validation.sh  # Validation
├── tests/                 # Test suite
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   ├── helpers/          # Test helpers
│   └── fixtures/         # Test data
├── data/                 # Data files
└── work_records/         # Generated work records
```

## Test execution

Structured tests:

```bash
# Main feature integration test
./tests/integration/test_main.sh

# Work table generation test
./tests/integration/test_work_table.sh

# Error scenario test
./tests/integration/test_error_scenarios.sh

# Fetch flow integration test
./tests/integration/test_fetch_flow.sh

# API unit test
./tests/unit/test_api.sh

# Configuration unit test
./tests/unit/test_config.sh

# Data processing unit test
./tests/unit/test_data.sh

# Output formatting unit test
./tests/unit/test_output.sh
```
