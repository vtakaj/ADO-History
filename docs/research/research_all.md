# Azure DevOps Work Record Extraction Tool Technical Stack Report

## Survey overview
The current implementation is a simple Bash-centered setup, with `ado-tracker.sh` as the entry point and split into multiple modules. It fetches Work Items and status history from the Azure DevOps REST API and generates a monthly work record table (Markdown).

## Technology stack
- bash
- curl (Azure DevOps API calls)
- jq (JSON processing)
- awk/sed (text processing)
- date (date calculations)

Note: jq may need to be installed in advance depending on the environment.

## Implementation structure
```
ado-tracker.sh          # Entry point (command router)
lib/core/               # API client, configuration, data processing, logging
lib/commands/           # Subcommand implementations
lib/formatters/         # Display/Markdown output
lib/utils/              # Date, string, file, validation utilities
DATA_DIR=./data/        # Fetched data storage location
work_records/           # Work record table output location
```

## Command list (current implementation)
```bash
./ado-tracker.sh fetch <project> [days] [--with-details]
./ado-tracker.sh status-history <project>
./ado-tracker.sh fetch-details <project>
./ado-tracker.sh generate-work-table <YYYY-MM> <file>
./ado-tracker.sh test-connection
./ado-tracker.sh config show|validate|template
```

## Data storage
```
./data/workitems.json
./data/status_history.json
./data/workitem_details.json   # Only when running --with-details or fetch-details
./data/backup/                 # Automatic backups
./data/checkpoint.json         # Checkpoint for resume
```

## Work record table generation
- Output format: Markdown
- Output location: `./work_records/YYYY-MM.md`
- Assignee filtering:
  - Use `--assignees` in the command
  - Or use `WORK_TABLE_ASSIGNEES` in `.env`

## Execution steps (example)
```bash
# Prepare .env in advance (AZURE_DEVOPS_PAT, AZURE_DEVOPS_ORG, etc.)

# Fetch the last 30 days
./ado-tracker.sh fetch MyProject 30

# Fetch with details
./ado-tracker.sh fetch MyProject 30 --with-details

# Generate monthly work record table
./ado-tracker.sh generate-work-table 2025-12 ./work_records/2025-12.md
```

## Automation (example)
There is no dedicated `auto-report` command in the current implementation. Automate by running `fetch` and `generate-work-table` sequentially via cron, etc.

```bash
# Example: generate the previous month at the start of each month
0 9 1 * * /path/to/ado-tracker.sh fetch MyProject 40 && \
  /path/to/ado-tracker.sh generate-work-table 2025-12 /path/to/work_records/2025-12.md
```

## Security
- Manage PAT via environment variables (.env) and do not commit it
- Recommended permissions for `.env` are 600
- Do not print secrets in logs

## Notes (not implemented)
- Commands such as `calculate`, `summary`, `auto-report`, and `export` do not exist in the current implementation
- Export to CSV/Excel/JSON is not supported (Markdown output only)
