# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `ado-history`, a Bash-based Azure DevOps ticket history extraction tool. The tool fetches Work Items and status histories from Azure DevOps REST API and generates work record tables.

## Essential Commands

### Main Tool Usage
```bash
# Display help
./ado-tracker.sh help

# Test API connection
./ado-tracker.sh test-connection

# Configuration management
./ado-tracker.sh config show
./ado-tracker.sh config validate
./ado-tracker.sh config template

# Fetch work items and status history
./ado-tracker.sh fetch ProjectName 30
./ado-tracker.sh fetch ProjectName 30 --with-details

# Generate work record tables
./ado-tracker.sh generate-work-table 2025-01 ./work_records/2025-01.md
```

### Testing
```bash
# Run main integration tests
./tests/integration/test_main.sh

# Run specific test suites
./tests/integration/test_work_table.sh
./tests/integration/test_error_scenarios.sh
./tests/integration/test_fetch_flow.sh

# Run unit tests
./tests/unit/test_api.sh
./tests/unit/test_config.sh
./tests/unit/test_data.sh
./tests/unit/test_output.sh
```

## Architecture

### Modular Structure
The codebase follows a clean modular architecture:

- **Main Script**: `ado-tracker.sh` (106 lines) - Lightweight entry point
- **Core Modules**: `/lib/core/` - API client, config management, data processing, logging
- **Commands**: `/lib/commands/` - Individual command implementations  
- **Formatters**: `/lib/formatters/` - Output formatting (markdown, display)
- **Utils**: `/lib/utils/` - Date, string, file, validation utilities
- **Tests**: `/tests/` - Comprehensive unit and integration test suite

### Key Components

1. **API Client** (`lib/core/api_client.sh`): Handles Azure DevOps REST API calls with error handling, exponential backoff retry, and rate limiting
2. **Data Processor** (`lib/core/data_processor.sh`): Processes and transforms API responses
3. **Config Manager** (`lib/core/config_manager.sh`): Manages environment variables and configuration validation
4. **Logger** (`lib/core/logger.sh`): Provides timestamped logging with different levels

### Data Flow
1. Configuration validation and API authentication
2. Work Items fetching with pagination support
3. Status history extraction for each Work Item
4. Data processing and JSON storage (`./data/`)
5. Markdown table generation from processed data

## Configuration

The tool requires these environment variables:
- `AZURE_DEVOPS_PAT`: Personal Access Token (required)
- `AZURE_DEVOPS_ORG`: Organization name (required)
- `AZURE_DEVOPS_PROJECT`: Project name (optional, can be passed as argument)

Configuration template can be generated with `./ado-tracker.sh config template`.

## Important Notes

- All shell scripts use `set -euo pipefail` for strict error handling
- The tool implements checkpoint/recovery functionality for interrupted operations
- Data is automatically backed up to `./data/backup/` before operations
- Japanese timezone (JST) is used for timestamp processing
- Tests use mock API responses and require no actual Azure DevOps connection