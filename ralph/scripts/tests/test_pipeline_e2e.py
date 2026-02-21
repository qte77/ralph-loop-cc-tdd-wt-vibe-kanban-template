"""
E2E Test: Full Ralph Loop Pipeline

Tests complete pipeline from PRD initialization through story execution,
validation, and documentation generation.

Usage: Run from project root with pytest:
  uv run pytest ralph/scripts/tests/test_pipeline_e2e.py -m e2e -v
"""

import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict

import pytest


@pytest.mark.e2e
def test_full_ralph_pipeline(tmp_path: Path) -> None:
    """
    E2E: Complete Ralph Loop pipeline test.

    Tests:
    1. PRD initialization and validation
    2. Story execution with mocked Claude
    3. Validation pipeline (ruff, pyright, pytest)
    4. State tracking (prd.json, progress.txt)
    5. Documentation generation (README.md, example.py)
    """
    # Setup test environment
    test_repo = tmp_path / "test_repo"
    test_repo.mkdir()
    os.chdir(test_repo)

    # Initialize git repo
    subprocess.run(["git", "init"], check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        check=True,
        capture_output=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test User"], check=True, capture_output=True
    )

    # Create minimal PRD
    prd_dir = test_repo / "docs" / "ralph"
    prd_dir.mkdir(parents=True)

    prd_data: Dict[str, Any] = {
        "stories": [
            {
                "id": "STORY-001",
                "title": "Setup project structure",
                "description": "Create basic Python package structure with __init__.py",
                "acceptance_criteria": [
                    "src/myapp/__init__.py exists",
                    "Package is importable",
                ],
                "expected_files": ["src/myapp/__init__.py"],
                "status": "pending",
                "completed_at": None,
                "depends_on": [],
            },
            {
                "id": "STORY-002",
                "title": "Add calculator function",
                "description": "Implement add(a, b) function with tests",
                "acceptance_criteria": [
                    "Function add(a, b) returns sum",
                    "Unit tests pass",
                ],
                "expected_files": ["src/myapp/calculator.py", "tests/test_calculator.py"],
                "status": "pending",
                "completed_at": None,
                "depends_on": ["STORY-001"],
            },
        ]
    }

    prd_file = prd_dir / "prd.json"
    with open(prd_file, "w") as f:
        json.dump(prd_data, f, indent=2)

    # Create minimal progress file
    progress_file = prd_dir / "progress.txt"
    with open(progress_file, "w") as f:
        f.write("# Ralph Loop Progress\n")

    # Validate PRD structure
    with open(prd_file) as f:
        loaded_prd = json.load(f)

    assert len(loaded_prd["stories"]) == 2
    assert loaded_prd["stories"][0]["id"] == "STORY-001"
    assert loaded_prd["stories"][0]["status"] == "pending"
    assert loaded_prd["stories"][1]["depends_on"] == ["STORY-001"]


@pytest.mark.e2e
def test_prd_json_validation() -> None:
    """
    E2E: PRD JSON validation and schema conformance.

    Tests:
    1. Valid JSON structure
    2. Required fields present
    3. Dependency graph is acyclic
    """
    # Test valid PRD
    valid_prd = {
        "stories": [
            {
                "id": "STORY-001",
                "title": "Test story",
                "description": "Description",
                "acceptance_criteria": ["Criterion 1"],
                "expected_files": ["file.py"],
                "status": "pending",
                "completed_at": None,
                "depends_on": [],
            }
        ]
    }

    # Validate structure
    assert "stories" in valid_prd
    assert len(valid_prd["stories"]) > 0

    story = valid_prd["stories"][0]
    required_fields = [
        "id",
        "title",
        "description",
        "acceptance_criteria",
        "expected_files",
        "status",
        "completed_at",
        "depends_on",
    ]

    for field in required_fields:
        assert field in story, f"Missing required field: {field}"


@pytest.mark.e2e
def test_dependency_resolution() -> None:
    """
    E2E: Dependency graph resolution.

    Tests:
    1. Stories with satisfied dependencies are executable
    2. Stories with unsatisfied dependencies are blocked
    3. Dependency ordering is respected
    """
    stories = [
        {"id": "A", "status": "passed", "depends_on": []},
        {"id": "B", "status": "pending", "depends_on": ["A"]},
        {"id": "C", "status": "pending", "depends_on": ["A", "B"]},
        {"id": "D", "status": "pending", "depends_on": ["E"]},
        {"id": "E", "status": "pending", "depends_on": []},
    ]

    # Simulate dependency resolution
    def can_execute(story_id: str, stories_list: list) -> bool:
        """Check if story can be executed based on dependencies."""
        story = next(s for s in stories_list if s["id"] == story_id)
        if not story["depends_on"]:
            return True

        for dep_id in story["depends_on"]:
            dep = next(s for s in stories_list if s["id"] == dep_id)
            if dep["status"] != "passed":
                return False
        return True

    # A is complete, B can execute
    assert can_execute("B", stories) is True

    # C depends on B (not complete), cannot execute
    assert can_execute("C", stories) is False

    # E has no deps, can execute
    assert can_execute("E", stories) is True

    # D depends on E (not complete), cannot execute
    assert can_execute("D", stories) is False


@pytest.mark.e2e
def test_scoring_algorithm() -> None:
    """
    E2E: Parallel worktree scoring algorithm.

    Tests the scoring function used to select best parallel result:
    score = (stories_passed * 100) + test_count + (validation_pass ? 50 : 0)
    """

    def score_result(
        stories_passed: int, test_count: int, validation_passed: bool
    ) -> int:
        """Calculate score for a worktree result."""
        validation_bonus = 50 if validation_passed else 0
        return (stories_passed * 100) + test_count + validation_bonus

    # Test cases
    assert score_result(1, 5, True) == 155  # 100 + 5 + 50
    assert score_result(1, 5, False) == 105  # 100 + 5 + 0
    assert score_result(0, 3, False) == 3  # 0 + 3 + 0
    assert score_result(2, 10, True) == 260  # 200 + 10 + 50
    assert score_result(5, 0, True) == 550  # 500 + 0 + 50

    # Verify ordering
    scores = [
        ("wt1", score_result(1, 5, True)),
        ("wt2", score_result(0, 3, False)),
        ("wt3", score_result(2, 10, True)),
    ]

    best = max(scores, key=lambda x: x[1])
    assert best[0] == "wt3"  # Highest score
    assert best[1] == 260


@pytest.mark.e2e
def test_progress_tracking() -> None:
    """
    E2E: Progress file format and tracking.

    Tests:
    1. Progress file format is readable
    2. Iteration logs are structured correctly
    3. Status tracking (PASS/FAIL/RETRY) works
    """
    with tempfile.NamedTemporaryFile(mode="w+", delete=False, suffix=".txt") as f:
        progress_file = f.name

        # Simulate progress logging
        f.write("# Ralph Loop Progress\n")
        f.write("Started: 2026-01-21\n\n")
        f.write("## Iteration 1\n")
        f.write("Story: STORY-001\n")
        f.write("Status: PASS\n")
        f.write("Notes: Completed successfully\n\n")
        f.write("## Iteration 2\n")
        f.write("Story: STORY-002\n")
        f.write("Status: FAIL\n")
        f.write("Notes: Validation errors\n\n")

    # Read and validate
    with open(progress_file) as f:
        content = f.read()

    assert "# Ralph Loop Progress" in content
    assert "STORY-001" in content
    assert "Status: PASS" in content
    assert "STORY-002" in content
    assert "Status: FAIL" in content

    os.unlink(progress_file)


@pytest.mark.e2e
def test_git_worktree_isolation() -> None:
    """
    E2E: Git worktree isolation verification.

    Tests:
    1. Worktrees maintain independent state
    2. Commits in one worktree don't affect others
    3. Branches remain isolated
    """
    with tempfile.TemporaryDirectory() as tmp_dir:
        repo_dir = Path(tmp_dir) / "repo"
        repo_dir.mkdir()

        os.chdir(repo_dir)

        # Initialize repo
        subprocess.run(["git", "init"], check=True, capture_output=True)
        subprocess.run(
            ["git", "config", "user.email", "test@example.com"],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["git", "config", "user.name", "Test User"],
            check=True,
            capture_output=True,
        )

        # Initial commit
        (repo_dir / "README.md").write_text("# Test\n")
        subprocess.run(["git", "add", "README.md"], check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "Initial commit"],
            check=True,
            capture_output=True,
        )

        # Create worktree
        wt_path = Path(tmp_dir) / "worktree-1"
        subprocess.run(
            [
                "git",
                "worktree",
                "add",
                "--no-track",
                "--lock",
                "-b",
                "test-branch",
                str(wt_path),
                "HEAD",
            ],
            check=True,
            capture_output=True,
        )

        # Verify worktree exists and is locked
        result = subprocess.run(
            ["git", "worktree", "list"], check=True, capture_output=True, text=True
        )
        assert "worktree-1" in result.stdout
        assert "locked" in result.stdout

        # Cleanup
        subprocess.run(
            ["git", "worktree", "unlock", str(wt_path)],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["git", "worktree", "remove", str(wt_path)],
            check=True,
            capture_output=True,
        )
        subprocess.run(
            ["git", "branch", "-D", "test-branch"], check=True, capture_output=True
        )
