## ADDED Requirements

### Requirement: fetch command uses days-only positional argument
The system SHALL accept the fetch command in the form `fetch <days>` and MUST treat the first positional argument as the days value.

#### Scenario: Valid days argument
- **WHEN** the user runs `./ado-tracker.sh fetch 30`
- **THEN** the system parses `30` as the days value and proceeds with fetch

### Requirement: fetch command rejects project positional argument
The system MUST NOT accept a project name as a positional argument to `fetch` and SHALL report an error if extra positional arguments are provided.

#### Scenario: Extra positional argument
- **WHEN** the user runs `./ado-tracker.sh fetch MyProject 30`
- **THEN** the system reports an error indicating extra arguments are not allowed

### Requirement: fetch supports --with-details option
The system SHALL accept the `--with-details` option with `fetch` and MUST perform the fetch with details enabled.

#### Scenario: Fetch with details
- **WHEN** the user runs `./ado-tracker.sh fetch 7 --with-details`
- **THEN** the system performs the fetch and includes detailed work item data

