# Ralph Loop + Vibe Kanban Integration

## Overview

Ralph Loop can push task status to Vibe Kanban via
REST API for real-time visual monitoring.
This is a **uni-directional read-only integration** - Vibe Kanban displays
Ralph's state without controlling it.

## Architecture

```text
Ralph Loop (Orchestrator)
  ├─> Manages worktrees (../ralph-wt-*)
  ├─> Runs Claude Code agents
  ├─> Enforces TDD workflow
  └─> REST API
              └─> Web UI Display
```

**Key Points:**

- Ralph remains the orchestrator (creates worktrees, runs agents)
- Vibe Kanban is DISPLAY ONLY (shows status, doesn't launch agents)
- Integration via REST API: `create_task`, `update_task`
- Uni-directional: Ralph → Vibe Kanban (read-only monitoring)

## Quick Start

### Real Ralph Integration

```bash
# Terminal 1: Start Vibe Kanban
make vibe_start          # Starts on port 5173

# Terminal 2: Run Ralph (auto-syncs in real-time)
make ralph_run N_WT=3

# Stop when done
make vibe_stop_all
```

Ralph will:

1. Auto-detect Vibe Kanban on configured port (default: 5173)
2. Create tasks from prd.json (all start as "todo")
3. Update status in real-time:
   - Story starts → "inprogress"
   - Story passes → "done"
   - Story fails → "todo"
4. Works across all parallel worktrees simultaneously

## Configuration

### Port Configuration

Default port: **5173** (configured in `ralph/scripts/lib/config.sh`)

**To change port:**

```bash
# Set in config.sh
RALPH_VIBE_PORT=8080

# Or override at runtime
RALPH_VIBE_PORT=8080 make vibe_start
RALPH_VIBE_PORT=8080 make ralph_run
```

Ralph auto-detects Vibe Kanban at the configured port and syncs automatically.

## REST API Integration

Ralph uses Vibe Kanban REST API endpoints:

### API Attributes Reference

**Project Attributes:**

```json
{
  "id": "uuid",                           // Project unique identifier
  "name": "string",                       // Project name
  "default_agent_working_dir": "string",  // Default working directory
  "remote_project_id": "uuid | null",     // Remote project reference
  "created_at": "ISO8601",                // Creation timestamp
  "updated_at": "ISO8601"                 // Last update timestamp
}
```

**Task Attributes:**

```json
{
  "id": "uuid",                           // Task unique identifier
  "project_id": "uuid",                   // Parent project UUID
  "title": "string",                      // Task title (Ralph format:
                                          // "[run_id] [WTn] STORY-ID: Title")
  "description": "string",                // Task description with
                                          // acceptance criteria
  "status": "string",                     // Status: todo|inprogress|inreview|done|cancelled
  "parent_workspace_id": "uuid | null",   // Parent workspace reference
  "created_at": "ISO8601",                // Creation timestamp
  "updated_at": "ISO8601",                // Last update timestamp
  "has_in_progress_attempt": "boolean",   // Whether task has active
                                          // attempt
  "last_attempt_failed": "boolean",       // Whether last attempt failed
  "executor": "string"                    // Executor identifier (Ralph
                                          // format: "ralph-loop:{RUN}:WT{n}")
}
```

### API Endpoints

#### GET /api/projects

Get project list to find Ralph project ID.

**Request:**

```bash
curl -s http://127.0.0.1:5173/api/projects
```

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "bc74b558-e1e1-4f20-91e2-c6fd33bb969f",
      "name": "your-project-name",
      "default_agent_working_dir": "",
      "remote_project_id": null,
      "created_at": "2026-01-22T13:50:36.549Z",
      "updated_at": "2026-01-22T13:50:36.549Z"
    }
  ],
  "error_data": null,
  "message": null
}
```

#### GET /api/tasks

Get all tasks for a project, with optional filtering.

**Request:**

```bash
curl -s "http://127.0.0.1:5173/api/tasks?\
project_id=bc74b558-e1e1-4f20-91e2-c6fd33bb969f"
```

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "edf39612-42bc-4bd3-9c8b-018d58e7bb26",
      "project_id": "bc74b558-e1e1-4f20-91e2-c6fd33bb969f",
      "title": "[df3d85] [WT1] STORY-001: Dataset Downloader",
      "description": "Download dataset\n\nAcceptance:\n- Download\n- Save",
      "status": "todo",
      "parent_workspace_id": null,
      "created_at": "2026-01-23T13:50:45.392Z",
      "updated_at": "2026-01-23T13:50:45.392Z"
    }
  ],
  "error_data": null,
  "message": null
}
```

**Query by status (with jq):**

```bash
# Get tasks grouped by status
curl -sf "http://127.0.0.1:5173/api/tasks?project_id=..." | \
  jq '.data | group_by(.status) | \
    map({status: .[0].status, count: length})'

# List all tasks by status
curl -sf "http://127.0.0.1:5173/api/tasks?project_id=..." | \
  jq -r '.data | group_by(.status) | .[] | \
    "\n=== \(.[0].status | ascii_upcase) ===", \
    (.[] | "  - \(.title)")'
```

#### POST /api/tasks

Create task for each story from prd.json.

**Request:**

```bash
curl -X POST http://127.0.0.1:5173/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "bc74b558-e1e1-4f20-91e2-c6fd33bb969f",
    "title": "[646db4] [WT1] STORY-001: Dataset Downloader",
    "description": "Download dataset\n\nAcceptance:\n- Download\n- Save",
    "status": "todo"
  }'
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "edf39612-42bc-4bd3-9c8b-018d58e7bb26",
    "project_id": "bc74b558-e1e1-4f20-91e2-c6fd33bb969f",
    "title": "[646db4] [WT1] STORY-001: Dataset Downloader",
    "description": "Download dataset\n\nAcceptance:\n- Download\n- Save",
    "status": "todo",
    "parent_workspace_id": null,
    "created_at": "2026-01-23T13:50:45.392Z",
    "updated_at": "2026-01-23T13:50:45.392Z"
  }
}
```

#### PUT /api/tasks/:id

Update task status during execution.

**Request:**

```bash
curl -X PUT \
  http://127.0.0.1:5173/api/tasks/edf39612-42bc-4bd3-9c8b-018d58e7bb26 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "inprogress",
    "executor": "ralph-loop:646db4:WT1",
    "has_in_progress_attempt": true,
    "last_attempt_failed": false
  }'
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "edf39612-42bc-4bd3-9c8b-018d58e7bb26",
    "project_id": "bc74b558-e1e1-4f20-91e2-c6fd33bb969f",
    "title": "[646db4] [WT1] STORY-001: Dataset Downloader",
    "description": "Download dataset\n\nAcceptance:\n- Download\n- Save",
    "status": "inprogress",
    "parent_workspace_id": null,
    "created_at": "2026-01-23T13:50:45.392Z",
    "updated_at": "2026-01-23T13:50:45.392Z"
  },
  "error_data": null,
  "message": null
}
```

**Note:** The API accepts `executor`, `has_in_progress_attempt`, and
`last_attempt_failed` in PUT requests, but these fields are not returned
in the response and may not persist. Only `status` field updates reliably.

## Status Lifecycle

| Status | When | Description |
| --- | --- | --- |
| `todo` | Initial, or failed | Story not started or returned to queue |
| `inprogress` | Story execution starts | Claude Code working on story |
| `inreview` | Quality checks running | Tests and validation in progress |
| `done` | Story passes | All acceptance criteria met |
| `cancelled` | MAX_ITERATIONS reached | Story incomplete after max attempts |

**Source**: `ralph/scripts/lib/vibe.sh` (kanban_init, kanban_update)

### Verified Status Transitions

All status transitions verified working via direct API testing:

- ✓ `todo` → `inprogress` → `inreview` → `done` → `cancelled` → `todo`

<!-- TODO: Verify if these issues still exist with vibe-kanban v0.1.17+ -->
**Known Issues:**

1. **All tasks moved to cancelled**: During Ralph runs, all tasks end up
   in `cancelled` status regardless of pass/fail. Completed stories
   (e.g., STORY-000, STORY-001 with `.status: "passed"`) remain in `todo` or
   move to `cancelled` instead of `done`.
2. **Already-passing stories not synced**: Stories with `.status: "passed"`
   in prd.json are not synced to Vibe at Ralph startup.
3. **Tracking fields not persisting**: `executor`, `has_in_progress_attempt`,
   `last_attempt_failed` return as defaults in API responses despite being
   sent in PUT requests.

### Task Tracking Fields

Ralph populates additional fields for execution tracking:

- **`executor`**: Format `ralph-loop:{RUN_ID}:WT{N}` (e.g.,
  "ralph-loop:eea6b0:WT1") - Identifies which Ralph run and worktree is
  handling the task
- **`has_in_progress_attempt`**: `true` for active work
  (`inprogress|inreview`), `false` otherwise
- **`last_attempt_failed`**: `true` for failures (`todo|cancelled`),
  `false` for success (`done`)

## Vibe Kanban Data Storage

Vibe Kanban stores all data locally in `~/.vibe/`:

```text
~/.vibe/
├── vibe.db              # SQLite database (projects, tasks, attempts)
├── profiles.json        # Agent configurations (custom overrides)
├── images/              # Uploaded task images/screenshots
└── logs/                # Execution logs
```

**Key Files:**

- `vibe.db` - All project and task state
- `profiles.json` - Custom agent configurations (GUI: Settings → Agents)

## Project Configuration

### Auto-Generated Project Config

Ralph initialization creates `.vibe-kanban/project.json` from template:

```bash
make ralph_init_loop
# or
./ralph/scripts/init.sh
```

Template location: `ralph/docs/templates/vibe-project.json.template`

**Variables populated:**

- `{{PROJECT_NAME}}` - From git repo or directory name
- `{{GIT_REPO_PATH}}` - Current directory (.)
- `{{WORKTREE_PREFIX}}` - From `RALPH_PARALLEL_WORKTREE_PREFIX`
- `{{PRD_PATH}}` - From `RALPH_PRD_JSON`
- `{{PROGRESS_PATH}}` - From `RALPH_PROGRESS_FILE`

## Sources

- [Vibe Kanban GitHub](https://github.com/BloopAI/vibe-kanban)
