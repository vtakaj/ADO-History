# User Story List

## Overview
This document lists the user stories for the Azure DevOps work record extraction tool.
It focuses on the minimum features for the PoC (proof of concept) phase.

## Story list

### PoC phase stories (minimum features)

| ID | Title | Priority | Description | Status |
|---|---|---|---|---|
| [US-001](./US-001.md) | Extract ticket history from Azure DevOps | High | Automatically fetch ticket status change history using the Azure DevOps API | Implemented |
| [US-002](./US-002.md) | Calculate work periods | High | Calculate the period from Doing start to Done completion and exclude Blocked periods | Not implemented |
| [US-003](./US-003.md) | Review team monthly work summary | High | View monthly work time and outcomes for the whole team | Not implemented |
| [US-004](./US-004.md) | Automatically generate monthly work summary | High | Generate a monthly summary report automatically at the end of the month | Not implemented |
| [US-005](./US-005.md) | Export team work reports | High | Export the team's monthly work report in multiple formats (JSON, Markdown, Excel) | Not implemented |

## Implementation priority

### PoC phase (overall)
1. US-001: Extract ticket history from Azure DevOps
2. US-002: Calculate work periods
3. US-003: Review team monthly work summary
4. US-004: Automatically generate monthly work summary
5. US-005: Export team work reports

## Technical requirements
- Use open source technologies
- Develop and deploy the prototype within 2 weeks
- Low-cost development
- Verify operation on a real Azure DevOps repository
