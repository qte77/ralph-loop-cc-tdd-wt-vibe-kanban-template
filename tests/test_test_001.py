"""Tests for TEST-001: Test Story."""

import os


def test_acceptance_criterion_1():
    """Acceptance criterion 1: test_file.txt must exist in the project root."""
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    test_file = os.path.join(project_root, "test_file.txt")
    assert os.path.exists(test_file), f"test_file.txt not found at {test_file}"
