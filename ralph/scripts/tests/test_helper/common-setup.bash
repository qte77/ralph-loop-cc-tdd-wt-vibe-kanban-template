#!/usr/bin/env bash
# Common setup/teardown helpers for BATS tests
# Provides:
#   - Isolated tmp directory per test (RALPH_TMP_DIR)
#   - Stubbed claude binary
#   - create_mock_prd() helper
#   - Git config for tests that create commits

# Create isolated tmp directory if not already set
if [ -z "${RALPH_TMP_DIR:-}" ]; then
    export RALPH_TMP_DIR
    RALPH_TMP_DIR="$(mktemp -d)"
fi

# Create stub claude binary in tmp dir
_setup_claude_stub() {
    local stub_path="${RALPH_TMP_DIR}/claude"

    if [ ! -f "$stub_path" ]; then
        cat > "$stub_path" << 'EOF'
#!/usr/bin/env bash
# Stubbed claude binary for testing - no-op
exit 0
EOF
        chmod +x "$stub_path"
    fi

    # Prepend tmp dir to PATH so stub is found first
    export PATH="${RALPH_TMP_DIR}:${PATH}"
}

# Helper to create a minimal valid prd.json
create_mock_prd() {
    local output_path="${1:-.}"

    cat > "$output_path" << 'EOF'
{
  "project": "Test Project",
  "description": "Test PRD for BATS tests",
  "source": "test",
  "generated": "2026-03-25T00:00:00Z",
  "stories": [
    {
      "id": "TEST-001",
      "title": "Test Story",
      "description": "Test story for testing",
      "depends_on": [],
      "acceptance": ["Acceptance criterion 1"],
      "files": ["test_file.txt"],
      "status": "pending",
      "wave": 1,
      "completed_at": null
    }
  ]
}
EOF
}

# Set git config for tests that need to create commits
_setup_git_config() {
    git config --global user.name "Test User" 2>/dev/null || true
    git config --global user.email "test@example.com" 2>/dev/null || true
}

# Run setup
_setup_claude_stub
_setup_git_config

# Export helper functions
export -f create_mock_prd
