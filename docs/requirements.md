# Azure DevOps Work Record Extraction Tool Requirements

## 1. Project overview

### 1.1 Project name
Fastener Drop Monitoring System Development Support

### 1.2 Purpose
Automatically extract daily and per-assignee work content (ticket numbers) from Azure DevOps Work Items and status history, and generate a monthly work record table (Markdown). Reduce manual aggregation and improve progress tracking.

## 2. Business requirements

### 2.1 Required features
- Fetch Work Items and status change history from the Azure DevOps REST API
- Save fetched data as JSON under `./data/`
- Generate a monthly work record table (Markdown)
- Allow filtering by assignee via command or `.env` settings

### 2.2 Data to collect
- Work Items: ID / title / assignee / status / last updated date
- Status history: change date / changed by / assignee / before and after status

## 3. Non-functional requirements

### 3.1 Runtime environment
- Environment with bash / curl / jq available
- Network access to Azure DevOps

### 3.2 Security
- Manage PAT via environment variables (do not commit if managed via `.env`)
- Recommended permissions for `.env` are 600

### 3.3 Operations
- Fetched data is automatically backed up under `./data/backup/`
- Save checkpoints for recovery to `./data/checkpoint.json`
- Timestamps are based on JST

## 4. Output example

### 4.1 Work record table (Markdown)
```
# Work Record Table (2025-12)

| Date | Day | Toshiki Haraguchi | Work | Takumi Oda | Work |
|------|-----|-------------------|------|------------|------|
| 2025/12/01 | Mon | #5433 #5421 | | #5447 | |
| 2025/12/02 | Tue | #5433 | | #5447 #5448 | |
| **Total** | | **--:--** | | **--:--** | |

## Ticket List (December 2025)
- **#5433**: Displacement Calculation Domain Modeling
- **#5447**: [ODC Improvement] Define response deadlines based on defect impact and require impact entry at creation
```

## 5. Constraints
- Azure DevOps PAT and organization information are required
- Assumes status history is recorded correctly
- Output format is Markdown only
