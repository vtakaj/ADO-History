# Capability: generate-work-table

## Overview

Outputs a monthly work record table in Markdown format. It lists active tickets per assignee on a daily basis using status history and Work Item data.

## Goals

- Generate a monthly work record table for the specified YYYY-MM
- Limit output to specified assignees when provided
- Output both the table and the ticket list section

## Non-goals

- Fetch data from Azure DevOps
- Modify Work Item state or history data
- Calculate metrics such as effort totals or durations

## Behavior

### Normal Flow

1. Verify the data files exist and generate the work table
   - data/workitems.json
   - data/status_history.json

2. Determine target assignees
   - Use --assignees if provided
   - Use WORK_TABLE_ASSIGNEES if --assignees is not provided
   - Otherwise extract assignees from status_history for the given month

3. Include the following in the output file
   - Title: `# Work Record Table (YYYY-MM)`
   - Table
     - Header: `| Date | Day | <Assignee> | Work | ... |`
     - Date: YYYY/MM/DD
     - Day: Japanese weekday (e.g., 月, 火, ...)
     - Work: Space-separated active ticket IDs for the assignee on that day
       - Ticket IDs are displayed with a `#` prefix
   - Footer: Total row
   - Ticket list section
     - Heading: `## Ticket List (YYYY年MM月)`
     - Format: `- **#<id>**: <title>`

4. Ticket list target scope
   - When assignees are specified: only tickets displayed in the table
   - When assignees are not specified: tickets that had status changes in the given month

### Output When Data Is Missing

- If no assignees are found for the given month, output a minimal document:
  - Title
  - Blank line
  - Message
    - With assignees specified: "No status history found for the specified assignees."
    - Without assignees specified: "No status history found for the specified month."

### Error Cases

1. Missing arguments
   - Error when year_month or output_file is not provided
2. Invalid year_month format
   - Error when format is not YYYY-MM
3. Missing data files
   - Error when workitems.json or status_history.json is missing

## Parameters

- Command line arguments
  - year_month (required)
    - Format: YYYY-MM
  - output_file (required)
    - Output path
  - --assignees (optional)
    - Comma- or semicolon-separated assignee list

- Environment variables
  - WORK_TABLE_ASSIGNEES (optional)
    - Assignee list used when --assignees is not provided

## Validation rules

- year_month MUST match ^[0-9]{4}-[0-9]{2}$
- output_file is required
- data/workitems.json and data/status_history.json must exist
