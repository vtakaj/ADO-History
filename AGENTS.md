# AGENTS.md

A short guide for agents working in this repository.

## Project overview
- A Bash tool that fetches Azure DevOps Work Items and status history, then generates a work record table
- Entry point: `./ado-tracker.sh`
- Fetched data is saved as JSON under `./data/`, and work records are output to `./work_records/`

## Main structure
- `ado-tracker.sh`: command router (lightweight)
- `lib/core/`: API client, configuration, data processing, logging
- `lib/commands/`: subcommand implementations
- `lib/formatters/`: display and markdown output
- `lib/utils/`: date, string, file, validation utilities
- `tests/`: unit / integration tests

## Key components
1. **API client** (`lib/core/api_client.sh`): Azure DevOps REST API calls, retry/rate limiting
2. **Data processing** (`lib/core/data_processor.sh`): extract and transform status history
3. **Configuration** (`lib/core/config_manager.sh`): load and validate environment variables
4. **Logging** (`lib/core/logger.sh`): timestamped log output

## Data flow
1. Load and validate configuration
2. Fetch Work Items
3. Fetch status history
4. Save JSON under `./data/` (with automatic backup)
5. Output markdown via `generate-work-table`

## Required/related environment variables
Required:
- `AZURE_DEVOPS_PAT`
- `AZURE_DEVOPS_ORG`

Optional:
- `AZURE_DEVOPS_PROJECT`
- `API_VERSION` (default 7.2)
- `LOG_LEVEL` (INFO|WARN|ERROR)
- `RETRY_COUNT`, `RETRY_DELAY`, `REQUEST_TIMEOUT`, `BATCH_SIZE`

## Common commands
```bash
# Help
./ado-tracker.sh help

# Connection test
./ado-tracker.sh test-connection

# Configuration
./ado-tracker.sh config show
./ado-tracker.sh config validate
./ado-tracker.sh config template

# Fetch (use AZURE_DEVOPS_PROJECT when project is not specified)
./ado-tracker.sh fetch ProjectName 30
./ado-tracker.sh fetch 30 --with-details
./ado-tracker.sh status-history
./ado-tracker.sh fetch-details

# Generate work record table
./ado-tracker.sh generate-work-table 2025-01 ./work_records/2025-01.md
```

## Tests
```bash
./tests/integration/test_main.sh
./tests/integration/test_work_table.sh
./tests/integration/test_error_scenarios.sh
./tests/integration/test_fetch_flow.sh
./tests/unit/test_api.sh
./tests/unit/test_config.sh
./tests/unit/test_data.sh
./tests/unit/test_output.sh
```
Tests use a mock API, so a live Azure DevOps connection is not required.

## Runtime notes
- All shell scripts assume `set -euo pipefail`
- Fetched data is automatically backed up under `./data/backup/`
- Checkpoint for resume: `./data/checkpoint.json`
- Timestamps are based on JST
- Do not commit secrets such as PATs (rotate immediately if leaked)
