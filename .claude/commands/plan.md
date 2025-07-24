# Create Implementation Plan from User Story

## Command Usage
`/plan [user story ID]`
- Example: `/plan US-001`

## Purpose
Create implementation planning based on user stories, decompose tasks, and prepare for the next implementation phase

## Important Notes
- Stop this command if no user story ID is specified
- Read `./docs/research/research_all.md` thoroughly
- Read `./docs/userstories/{user story ID}.md` thoroughly
- Do not use emojis in file descriptions
- Use `use context7` to reference the latest technical documentation
- Ensure task decomposition follows the INVEST principle for user stories

## Process Steps
1. **User Story Analysis**: Analyze the specified user story thoroughly
2. **Task Decomposition**: Break down the user story into implementable tasks
3. **Technical Planning**: Plan frontend, backend, and infrastructure components
4. **Documentation**: Create detailed planning documents for each component

## TODOs Included in Tasks
1. Decompose tasks based on the user story
2. Collect and systematically analyze related files, logs, and documentation
3. Decompose tasks into three categories: Frontend, Backend, and Infrastructure
4. **CRITICAL**: Ensure task granularity is suitable for 2-3 hours implementation by a human
   - Each task should be completable within 2-3 hours
   - Break down large tasks into smaller, manageable pieces
   - Focus on single responsibility principle for each task
5. Create individual task files for each decomposed task directly under `./docs/plans/{user story ID}`:
   - Frontend tasks: `./docs/plans/{user story ID}/{user story ID}-FE-{sequence}.md`
   - Backend tasks: `./docs/plans/{user story ID}/{user story ID}-BE-{sequence}.md`
   - Infrastructure tasks: `./docs/plans/{user story ID}/{user story ID}-INF-{sequence}.md`
   - Example: `/plan US-001` → `docs/plans/US-001/US-001-FE-001.md`, `US-001-FE-002.md`, `US-001-BE-001.md`, etc.
6. Create a task overview file:
   - Filename: `./docs/plans/{user story ID}/tasks-overview.md`
   - Include all tasks with their IDs, descriptions, and dependencies
7. Provide recommendations for the next phase (implement)

## Task Decomposition Guidelines
- **Task Size**: 2-3 hours maximum per task
- **Single Responsibility**: Each task should have one clear objective
- **Measurable Outcome**: Each task should have a clear completion criteria
- **Dependencies**: Clearly identify task dependencies
- **Testing**: Include testing tasks as separate items
- **Documentation**: Include documentation tasks as separate items

## Task ID Naming Convention
- **Format**: `{user story ID}-{component}-{sequence number}`
- **Components**: 
  - `FE` = Frontend
  - `BE` = Backend  
  - `INF` = Infrastructure
- **Sequence Number**: 3-digit zero-padded format (001, 002, 003, ...)
- **Examples**:
  - `US-001-FE-001` (US-001 Frontend Task 1)
  - `US-001-FE-002` (US-001 Frontend Task 2)
  - `US-001-BE-001` (US-001 Backend Task 1)
  - `US-001-INF-001` (US-001 Infrastructure Task 1)

## Output Files Structure
- **Directory**: `./docs/plans/{user story ID}/`
- **Task Overview**: `tasks-overview.md` (summary of all tasks)
- **Frontend Tasks**: `{user story ID}-FE-001.md`, `{user story ID}-FE-002.md`, etc.
- **Backend Tasks**: `{user story ID}-BE-001.md`, `{user story ID}-BE-002.md`, etc.
- **Infrastructure Tasks**: `{user story ID}-INF-001.md`, `{user story ID}-INF-002.md`, etc.

## Quality Criteria
- Tasks should be specific, measurable, achievable, relevant, and time-bound (SMART)
- Each task should be implementable within 2-3 hours
- Tasks should be independent and have clear dependencies
- Planning should consider technical constraints and requirements
- Documentation should be clear and actionable
- Include testing and documentation tasks as separate items
