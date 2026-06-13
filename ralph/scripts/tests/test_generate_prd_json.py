"""Characterization tests for generate_prd_json.

These pin the CURRENT behavior of the pure parsing/resolution functions so the
upcoming behavior-preserving refactor can be verified against a green baseline.
They import the script module directly (it is stdlib-only) and do not touch any
existing test files.

Run (template pyproject has placeholders, so use an isolated env):
  uv run --no-project --with pytest pytest ralph/scripts/tests/test_generate_prd_json.py -q
"""

import sys
from pathlib import Path

# generate_prd_json.py lives one level up from this tests/ dir.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import generate_prd_json as g  # noqa: E402


# --- Fixture PRD -----------------------------------------------------------

PRD = """\
---
title: PRD for **DemoProj**
description: A demo project.
version: 1.0
---

## Features

#### Feature 1: Core Engine

**Description**: The core engine feature.

**Acceptance Criteria**:

- [ ] Engine starts
- [ ] Engine stops

**Files**:

- `src/engine.py`

#### Feature 2: Storage

**Description**: Storage subsystem.

**Acceptance Criteria**:

- [ ] Saves data

**Files**:

- `src/storage.py`

##### 2.1 Cache Layer

**Acceptance Criteria**:

- [ ] Cache hits

**Files**:

- `src/cache.py`

##### 2.2 Disk Layer

**Acceptance Criteria**:

- [ ] Disk writes

**Files**:

- `src/disk.py`

## Notes for Ralph Loop

### Story Breakdown (3 stories):

- **Feature 1** → STORY-001: Build engine
- **Feature 2 (Cache Layer)** → STORY-002: Add cache (depends: STORY-001)
- **Feature 2.1** → STORY-003: Cache detail
"""


# --- Pure helpers ----------------------------------------------------------

def test_compute_hash_is_deterministic_64_hex():
    h1 = g.compute_hash("t", "d", ["a", "b"])
    h2 = g.compute_hash("t", "d", ["a", "b"])
    assert h1 == h2
    assert len(h1) == 64
    assert all(c in "0123456789abcdef" for c in h1)


def test_compute_hash_changes_with_content():
    assert g.compute_hash("t", "d", ["a"]) != g.compute_hash("t", "d", ["b"])


def test_story_sort_key():
    assert g.story_sort_key("STORY-003") == (3, "")
    assert g.story_sort_key("STORY-010b") == (10, "b")
    assert g.story_sort_key("STORY-010") < g.story_sort_key("STORY-010b")


def test_extract_project_name_variants():
    assert g.extract_project_name({"title": "PRD for **DemoProj**"}) == "DemoProj"
    assert g.extract_project_name({"title": "Plan for MyThing"}) == "MyThing"
    assert g.extract_project_name({"title": "Just A Title"}) == "Just A Title"
    assert g.extract_project_name({}) == "Unknown Project"


def test_parse_frontmatter():
    fm = g.parse_frontmatter(PRD)
    assert fm["description"] == "A demo project."
    assert fm["version"] == "1.0"


def test_parse_depends():
    assert g._parse_depends("STORY-001, STORY-002b") == ["STORY-001", "STORY-002b"]
    assert g._parse_depends(None) == []
    assert g._parse_depends("") == []


# --- Feature parsing -------------------------------------------------------

def test_parse_features_with_subfeatures():
    feats = g.parse_features(PRD)
    assert set(feats.keys()) == {"1", "2"}
    assert feats["1"]["name"] == "Core Engine"
    assert "Engine starts" in feats["1"]["acceptance"]
    assert feats["1"]["files"] == ["src/engine.py"]
    subs = feats["2"].get("sub_features")
    assert subs is not None
    assert {s["number"] for s in subs.values()} == {"2.1", "2.2"}


# --- Story breakdown + resolution ------------------------------------------

def test_parse_story_breakdown_specs():
    specs = g.parse_story_breakdown(PRD)
    ids = [s["id"] for s in specs]
    assert ids == ["STORY-001", "STORY-002", "STORY-003"]
    s2 = next(s for s in specs if s["id"] == "STORY-002")
    assert s2["label"] == "Cache Layer"
    assert s2["depends_on"] == ["STORY-001"]
    s3 = next(s for s in specs if s["id"] == "STORY-003")
    assert s3["feature_id"] == "2.1"


def test_resolve_stories_dotted_subfeature_and_merge():
    specs = g.parse_story_breakdown(PRD)
    feats = g.parse_features(PRD)
    stories = g.resolve_stories(specs, feats)
    by_id = {s["id"]: s for s in stories}

    # STORY-003 uses dotted ID -> exact sub-feature 2.1 (Cache Layer)
    assert by_id["STORY-003"]["acceptance"] == ["Cache hits"]
    assert by_id["STORY-003"]["files"] == ["src/cache.py"]

    # STORY-002 is the only non-dotted story on feature 2 -> merges all sub-features
    assert "Saves data" in by_id["STORY-002"]["acceptance"]
    assert "Cache hits" in by_id["STORY-002"]["acceptance"]
    assert "Disk writes" in by_id["STORY-002"]["acceptance"]

    # STORY-001 -> feature-level data
    assert by_id["STORY-001"]["acceptance"] == ["Engine starts", "Engine stops"]
    assert by_id["STORY-001"]["depends_on"] == []
    assert by_id["STORY-001"]["content_hash"]


# --- Waves -----------------------------------------------------------------

def test_compute_waves_linear():
    specs = g.parse_story_breakdown(PRD)
    feats = g.parse_features(PRD)
    stories = g.resolve_stories(specs, feats)
    g.compute_waves(stories)
    by_id = {s["id"]: s for s in stories}
    assert by_id["STORY-001"]["wave"] == 1
    assert by_id["STORY-003"]["wave"] == 1
    assert by_id["STORY-002"]["wave"] == 2  # depends on STORY-001


def test_compute_waves_circular_falls_back_to_zero():
    a: g.Story = {
        "id": "STORY-001", "title": "a", "description": "", "acceptance": [],
        "files": [], "status": "pending", "wave": 0, "completed_at": None,
        "content_hash": "x", "depends_on": ["STORY-002"],
    }
    b: g.Story = {
        "id": "STORY-002", "title": "b", "description": "", "acceptance": [],
        "files": [], "status": "pending", "wave": 0, "completed_at": None,
        "content_hash": "y", "depends_on": ["STORY-001"],
    }
    g.compute_waves([a, b])
    assert a["wave"] == 0
    assert b["wave"] == 0


def test_compute_waves_passed_story_is_wave_zero():
    done: g.Story = {
        "id": "STORY-001", "title": "a", "description": "", "acceptance": [],
        "files": [], "status": "passed", "wave": 5, "completed_at": "t",
        "content_hash": "x", "depends_on": [],
    }
    nxt: g.Story = {
        "id": "STORY-002", "title": "b", "description": "", "acceptance": [],
        "files": [], "status": "pending", "wave": 0, "completed_at": None,
        "content_hash": "y", "depends_on": ["STORY-001"],
    }
    g.compute_waves([done, nxt])
    assert done["wave"] == 0
    assert nxt["wave"] == 1  # dep already passed/placed


# --- Backfill / migration --------------------------------------------------

def test_backfill_migrates_legacy_passes_to_status():
    stories = [{"id": "STORY-001", "title": "t", "description": "d",
                "acceptance": [], "passes": True}]
    passed, updated = g._backfill_existing_stories(stories)  # type: ignore[arg-type]
    assert stories[0]["status"] == "passed"
    assert "passes" not in stories[0]
    assert passed == 1


def test_backfill_protects_passed_story_fields():
    # A passed story missing content_hash is NOT given one (protected/short-circuit).
    stories = [{"id": "STORY-001", "title": "t", "description": "d",
                "acceptance": [], "status": "passed"}]
    g._backfill_existing_stories(stories)  # type: ignore[arg-type]
    assert "content_hash" not in stories[0]


def test_backfill_fills_missing_fields_on_incomplete():
    stories = [{"id": "STORY-001", "title": "t", "description": "d",
                "acceptance": ["x"], "status": "pending"}]
    _, updated = g._backfill_existing_stories(stories)  # type: ignore[arg-type]
    assert stories[0]["content_hash"]
    assert stories[0]["depends_on"] == []
    assert stories[0]["wave"] == 0
    assert updated == 1


# --- Unit tests for the newly extracted helpers ----------------------------

def test_lookup_feature_direct_dotted_missing():
    feats = g.parse_features(PRD)
    direct = {"id": "S", "title": "t", "feature_id": "1", "label": "", "depends_on": []}
    f, sub = g._lookup_feature(direct, feats)  # type: ignore[arg-type]
    assert f is feats["1"] and sub is None

    dotted = {"id": "S", "title": "t", "feature_id": "2.1", "label": "", "depends_on": []}
    f2, sub2 = g._lookup_feature(dotted, feats)  # type: ignore[arg-type]
    assert f2 is feats["2"] and sub2 == "2.1"

    missing = {"id": "S", "title": "t", "feature_id": "99", "label": "", "depends_on": []}
    f3, sub3 = g._lookup_feature(missing, feats)  # type: ignore[arg-type]
    assert f3 is None and sub3 is None


def test_resolve_sub_or_fallback_exact_and_fallback():
    feats = g.parse_features(PRD)
    feature2 = feats["2"]
    spec = {"id": "S", "title": "t", "feature_id": "2", "label": "", "depends_on": []}
    acc, files = g._resolve_sub_or_fallback(spec, feature2, [spec], "2.1")  # type: ignore[arg-type]
    assert acc == ["Cache hits"] and files == ["src/cache.py"]
    # No sub_number -> fallback; single story on feature 2 merges all sub-features.
    acc2, _ = g._resolve_sub_or_fallback(spec, feature2, [spec], None)  # type: ignore[arg-type]
    assert "Saves data" in acc2


def test_migrate_legacy_passes():
    s = {"id": "X", "passes": True}
    assert g._migrate_legacy_passes(s) is True  # type: ignore[arg-type]
    assert s["status"] == "passed" and "passes" not in s

    s2 = {"id": "X", "passes": False}
    assert g._migrate_legacy_passes(s2) is True  # type: ignore[arg-type]
    assert s2["status"] == "pending"

    # status already present -> no migration
    s3 = {"id": "X", "status": "pending", "passes": True}
    assert g._migrate_legacy_passes(s3) is False  # type: ignore[arg-type]
    assert g._migrate_legacy_passes({"id": "X"}) is False  # type: ignore[arg-type]


def test_fill_missing_fields_is_idempotent():
    s = {"id": "X", "title": "t", "description": "d", "acceptance": ["a"]}
    assert g._fill_missing_fields(s) is True  # type: ignore[arg-type]
    assert s["content_hash"] and s["depends_on"] == [] and s["status"] == "pending"
    assert g._fill_missing_fields(s) is False  # type: ignore[arg-type]


def test_check_declared_story_count_warns(capsys):
    g._check_declared_story_count("Story Breakdown (3 stories):", 2)
    out = capsys.readouterr().out
    assert "WARNING" in out and "3" in out and "2" in out
    g._check_declared_story_count("Story Breakdown (3 stories):", 3)
    assert "WARNING" not in capsys.readouterr().out


def test_write_prd_json_roundtrip(tmp_path):
    import json

    out = tmp_path / "sub" / "prd.json"
    stories = [{"id": "STORY-001", "title": "t"}]
    g._write_prd_json(out, "Proj", "desc", "PRD.md", stories)  # type: ignore[arg-type]
    data = json.loads(out.read_text())
    assert data["project"] == "Proj"
    assert data["description"] == "desc"
    assert data["source"] == "PRD.md"
    assert "generated" in data
    assert data["stories"] == stories
