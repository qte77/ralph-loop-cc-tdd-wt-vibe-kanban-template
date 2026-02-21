# Product Requirements Document: AgentEvals

## Project Overview

**Project Name**: AgentEvals

**Description**: A three-tiered evaluation framework for multi-agent AI
systems that provides objective benchmarking of autonomous agent teams. Uses
the PeerRead dataset to generate and evaluate scientific paper reviews through
traditional metrics, LLM-as-a-Judge assessment, and graph-based complexity
analysis.

**Goals**:

- Provide standardized, reproducible evaluation of multi-agent system outputs
- Enable objective comparison of different agent implementations
- Deliver multi-tiered insights combining performance, semantic, and structural
  metrics

**Target Users**: AI Researchers and ML Engineers working with multi-agent systems

## Architecture

**Design Philosophy**: Plugin-based evaluation framework powered by
OpenTelemetry observability data.

```text
┌─────────────────────────────────────────────────┐
│         PRIMARY: OpenTelemetry Traces           │
│    (Logfire recommended, any OTel backend)      │
└─────────────────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────┐
│      INDEPENDENT PLUGIN MODULES                 │
│      (No dependencies between plugins)          │
├────────────┬────────────┬────────────┬──────────┤
│   Graph    │   Text     │    Perf    │  LLM-as  │
│  Plugin    │  Metrics   │  Metrics   │  -Judge  │
│            │  Plugin    │  Plugin    │  Plugin  │
├────────────┼────────────┼────────────┼──────────┤
│ - Extract  │ - Leven.   │ - Exec time│ - Can    │
│   graphs   │ - Jaro-W.  │ - Success  │   analyze│
│ - NetworkX │ - Cosine   │ - Coord.   │   ANY    │
│   formal.  │            │            │   plugin │
│            │            │            │   output │
└────────────┴────────────┴────────────┴──────────┘
```

**Key Principles**:

- **OpenTelemetry Standard**: Not locked to specific vendor - any OTel backend works
- **Logfire Recommended**: Ease of use with PydanticAI + Logfire MCP for debugging
- **Local Development**: Opik or other OTel tools for local development
- **Plugin Architecture**: ALL modules are independent plugins with no
  inter-plugin dependencies
- **LLM-as-a-Judge Multi-Mode**: Special plugin that can analyze outputs
  from ANY other plugin
- **Composable Design**: Mix and match plugins based on evaluation needs

## Technical Requirements

### Core Dependencies

| Package           | Version  | Purpose                                    |
| ----------------- | -------- | ------------------------------------------ |
| pydantic-ai-slim  | >=0.8.1  | Agent framework with OpenAI/Tavily plugins |
| pydantic          | >=2.10.6 | Data validation                            |
| pydantic-settings | >=2.9.1  | Configuration management                   |

### Graph Analysis

| Package  | Version | Purpose                                          |
| -------- | ------- | ------------------------------------------------ |
| networkx | >=3.6   | Graph creation, manipulation, complexity metrics |

### Evaluation Metrics

| Package      | Version | Purpose                                        |
| ------------ | ------- | ---------------------------------------------- |
| rapidfuzz    | >=3.0   | Fast string similarity (Levenshtein, Jaro-W.)  |
| scikit-learn | >=1.7   | ML metrics (F1, precision, recall, cosine sim) |

### Observability (OpenTelemetry-Based)

**Standard**: OpenTelemetry traces/spans for capturing agent interactions.

**Goal**: Extract graph structures from OTel traces and formalize with NetworkX.

| Package | Version | Purpose                                         |
| ------- | ------- | ----------------------------------------------- |
| loguru  | >=0.7   | Local structured logging                        |
| logfire | >=3.16  | **Recommended** OTel backend (PydanticAI native)|
| weave   | >=0.51  | W&B integration (optional)                      |

**Why Logfire (Recommended)**:

- Native PydanticAI integration: `logfire.instrument_pydantic_ai()`
- Logfire MCP for AI-assisted debugging
- Same vendor as PydanticAI (Pydantic team)

**Alternative OTel Backends**:

- **Opik**: For local development with built-in evaluation metrics
- **Jaeger**: Open-source distributed tracing
- **Any OpenTelemetry-compatible backend**: Framework is not vendor-locked

#### Developer Tooling

- [Logfire MCP](https://github.com/pydantic/logfire-mcp) - AI-assisted trace
  debugging (requires Logfire)

Install:
`claude mcp add logfire -e LOGFIRE_READ_TOKEN="..." -- uvx logfire-mcp@latest`

### Data Processing

| Package | Version | Purpose                         |
| ------- | ------- | ------------------------------- |
| httpx   | >=0.28  | Async HTTP client for API calls |

## Functional Requirements

### Core Features

#### Feature 0: Configuration & Core Data Models

**Description**: Establish foundation with JSON configuration management and
shared Pydantic data models to prevent duplication across evaluation modules.

**User Stories**:

- As a developer, I want centralized configuration management so that settings
  are separated from code and easily maintainable
- As a developer, I want shared data models so that I avoid duplication and
  ensure consistency across modules

**Acceptance Criteria**:

- [ ] Create JSON config loader in `src/agenteval/config/`
- [ ] Load configuration at application runtime
- [ ] Define core Pydantic models: Paper, Review, Evaluation, Metrics, Report
- [ ] Models are reusable across all evaluation modules
- [ ] Pass all tests in `tests/test_config.py` and `tests/test_models.py`

**Technical Requirements**:

- Use pydantic-settings for configuration management
- JSON format for config files
- Type-safe Pydantic models with validation
- Configuration separated from implementation

**Files Expected**:

- `src/agenteval/config/__init__.py` - Config loader
- `src/agenteval/config/config.py` - Configuration schema
- `src/agenteval/models/__init__.py` - Core models
- `src/agenteval/models/data.py` - Paper, Review models
- `src/agenteval/models/evaluation.py` - Evaluation, Metrics, Report models
- `tests/test_config.py` - Config tests
- `tests/test_models.py` - Model tests
- `src/agenteval/config/default.json` - Default configuration

---

#### Feature 1: Dataset Downloader & Persistence

**Description**: Download PeerRead dataset and persist locally with versioning
for reproducibility and offline use.

**User Stories**:

- As a researcher, I want to download the PeerRead dataset once so that I can
  work offline and ensure reproducible experiments

**Acceptance Criteria**:

- [ ] Download PeerRead dataset from source
- [ ] Save dataset locally in structured format
- [ ] Implement versioning and checksums for integrity verification
- [ ] Verify dataset completeness after download
- [ ] Pass all tests in `tests/test_downloader.py`

**Technical Requirements**:

- Use httpx for async downloads
- Store in `data/peerread/` directory
- Include version metadata and checksums
- Graceful handling of network errors

**Files Expected**:

- `src/agenteval/data/downloader.py` - Dataset downloader
- `tests/test_downloader.py` - Downloader tests

---

#### Feature 2: Dataset Loader & Parser

**Description**: Load and parse PeerRead dataset from local storage into
structured Pydantic models.

**User Stories**:

- As a developer, I want to load PeerRead data from local storage so that
  evaluation modules can access structured paper and review data

**Acceptance Criteria**:

- [ ] Load PeerRead dataset from local storage
- [ ] Parse into Pydantic models (Paper, Review from Feature 0)
- [ ] Support batch loading of multiple papers
- [ ] Return structured data format for downstream processing
- [ ] Pass all tests in `tests/test_peerread.py`

**Technical Requirements**:

- Load from `data/peerread/` directory
- Parse into models defined in Feature 0
- Efficient batch processing
- Error handling for corrupted data

**Files Expected**:

- `src/agenteval/data/peerread.py` - PeerRead dataset loader
- `tests/test_peerread.py` - Loader tests

---

#### Feature 3: Traditional Performance Metrics

**Description**: Measure agent system performance with standard metrics for
objective comparison of implementations.

**User Stories**:

- As an ML engineer, I want to measure agent system performance with standard
  metrics so that I can compare different implementations objectively

**Acceptance Criteria**:

- [ ] Calculate execution time metrics for agent task completion
- [ ] Measure task success rate across evaluation runs
- [ ] Assess coordination quality between agents
- [ ] Output metrics in structured JSON format
- [ ] Support batch evaluation of multiple agent outputs

**Technical Requirements**:

- Use PydanticAI for agent implementation
- JSON output format for metrics
- Deterministic results with seed configuration

**Files Expected**:

- `src/agenteval/metrics/traditional.py` - Traditional metrics calculation
- `tests/test_traditional.py` - Tests for traditional metrics

---

#### Feature 4: LLM-as-a-Judge Evaluation

**Description**: Evaluate semantic quality of provided agent outputs using
LLM-based assessment against human baseline reviews from PeerRead dataset.

**User Stories**:

- As a researcher, I want LLM-based quality assessment so that I can evaluate
  semantic review quality beyond traditional metrics

**Acceptance Criteria**:

- [ ] Evaluate semantic quality of provided agent-generated reviews
- [ ] Compare agent outputs against human baseline reviews from PeerRead
- [ ] Provide scoring with justification from LLM judge
- [ ] Support configurable evaluation criteria
- [ ] Use mock/sample agent outputs for testing
- [ ] Pass all tests in `tests/test_llm_judge.py`

**Technical Requirements**:

- PydanticAI for LLM judge agent
- Use PeerRead human reviews as baseline (loaded via Feature 2)
- Structured evaluation output with scores and reasoning
- Agent outputs provided as input (not generated by this module)

**Files Expected**:

- `src/agenteval/judges/__init__.py` - Judge module init
- `src/agenteval/judges/llm_judge.py` - LLM-as-a-Judge implementation
- `tests/test_llm_judge.py` - Tests for LLM judge

---

#### Feature 5: Graph-Based Complexity Analysis

**Data Source**: OpenTelemetry traces (any OTel-compatible backend)

**Goal**: Extract graph structures from OTel trace spans and formalize using NetworkX.

**Description**: Extract agent interaction graphs from OpenTelemetry traces and
perform structural complexity analysis using NetworkX formalization.

**User Stories**:

- As a data scientist, I want graph-based structural analysis so that I can
  understand agent interaction patterns and coordination complexity

**Acceptance Criteria**:

- [ ] Model agent interactions as graph structures using NetworkX
- [ ] Calculate complexity metrics (density, centrality, clustering
      coefficient) from interaction graphs
- [ ] Identify coordination patterns between agents
- [ ] Export graph data in JSON/GraphML format for external analysis
- [ ] Use mock/sample interaction data for testing
- [ ] Pass all tests in `tests/test_graph.py`

**Technical Requirements**:

- Use NetworkX for graph representation of agent interactions
- NetworkX-based complexity metrics (graph density, degree centrality,
  betweenness centrality, clustering coefficient)
- JSON/GraphML export format
- Agent interaction data provided as input (not collected by this module)

**Files Expected**:

- `src/agenteval/metrics/graph.py` - Graph-based metrics
- `tests/test_graph.py` - Tests for graph metrics

---

### Analyzer Plugins

All plugins operate independently with no inter-plugin dependencies.

| Plugin         | Input        | Output       | Notes                  |
| -------------- | ------------ | ------------ | ---------------------- |
| Graph Plugin   | OTel Traces  | Graphs       | NetworkX formalization |
| Text Metrics   | Reviews      | Similarity   | Leven., Jaro-W., Cos.  |
| Perf Metrics   | Traces       | Timing       | Time, success, coord.  |
| LLM-as-a-Judge | Plugin data  | Semantic     | Analyzes any plugin    |

---

#### Feature 6: Evaluation Pipeline Orchestrator

**Description**: Orchestrate the execution of all evaluation modules in
sequence with dependency management and reproducibility controls.

**User Stories**:

- As a researcher, I want a unified pipeline orchestrator so that I can run
  all three evaluation approaches together in the correct order

**Acceptance Criteria**:

- [ ] Run all three evaluation tiers (traditional, LLM judge, graph) in
      sequence
- [ ] Handle module dependencies correctly
- [ ] Support reproducible runs with seed configuration
- [ ] Collect results from all modules
- [ ] Pass results to reporting module
- [ ] Pass all tests in `tests/test_pipeline.py`

**Technical Requirements**:

- Pipeline orchestration for Features 3, 4, 5
- Seed-based reproducibility
- Error handling and graceful degradation
- Pass structured data between modules

**Files Expected**:

- `src/agenteval/pipeline.py` - Pipeline orchestrator
- `tests/test_pipeline.py` - Pipeline integration tests

---

#### Feature 7: Consolidated Reporting & Observability

**Description**: Combine results from all evaluation tiers into unified reports
with integrated observability for debugging and monitoring.

**User Stories**:

- As a researcher, I want consolidated reports so that I can view all
  evaluation results in one place
- As a developer, I want observability so that I can debug and monitor
  evaluation runs

**Acceptance Criteria**:

- [ ] Combine results from all three evaluation tiers
- [ ] Generate consolidated JSON report with all metrics
- [ ] Integrate loguru for local console tracing by default
- [ ] Support optional Logfire/Weave cloud export via configuration
- [ ] Output combined results in structured format
- [ ] Pass all tests in `tests/test_report.py`

**Technical Requirements**:

- Consolidated JSON report format combining all tier results
- Local console tracing by default (loguru)
- Optional Logfire/Weave cloud export via config (from Feature 0)
- Report schema using models from Feature 0

**Files Expected**:

- `src/agenteval/report.py` - Report generation and observability
- `tests/test_report.py` - Report tests

---

## Non-Functional Requirements

### Performance

- Evaluation runs efficiently on standard research computing resources
- Batch processing of multiple papers without memory issues

### Reproducibility

- Consistent evaluation results across multiple runs with same seed
- Version-locked dependencies via uv.lock
- PeerRead dataset downloaded and saved locally for offline reproducibility

### Configuration Management

- All configuration stored in `src/agenteval/config/` directory
- Configuration files must be JSON format
- Configuration separated from implementation code
- Application loads configuration at runtime

### Code Quality

- All code must pass `make validate` (ruff, pyright, pytest)
- Follow KISS, DRY, YAGNI principles
- Python 3.13+ with modern typing features
- Test-driven development with pytest

## Out of Scope

- Production deployment infrastructure or scaling
- Real-time streaming evaluation of agent outputs
- Support for agent frameworks beyond PydanticAI
- Multi-language support for non-English reviews
- **Review-generation agents**: This framework evaluates agent outputs, not
  generates them. Test data should use mock/sample agent outputs or integrate
  with external agent systems

## Notes for Ralph Loop

When using the `/generating-prd-json-from-prd-md` skill to convert this PRD to `ralph/docs/prd.json`:

1. Each feature becomes a separate sprint/phase
2. Stories should be implementable in a single context window
3. Acceptance criteria become the `acceptance` field
4. Files expected become the `files` field

### Story Breakdown (Sequential Execution)

**Foundation (Must Complete First):**

- **STORY-000: Configuration & Core Data Models**
  - Create JSON config loader (`src/agenteval/config/`)
  - Define core Pydantic models (Paper, Review, Evaluation, Metrics, Report)
  - Prevent duplicate model definitions across stories (DRY principle)
  - Foundation for all subsequent stories

**Data Layer (Sequential Dependencies):**

- **STORY-001: Dataset Downloader & Persistence**
  - Download PeerRead dataset from source
  - Save locally with versioning/checksums
  - Verify dataset integrity
  - One-time infrastructure setup

- **STORY-002: Dataset Loader & Parser**
  - Load PeerRead data from local storage
  - Parse into Pydantic models (defined in STORY-000)
  - Batch loading API
  - Requires: STORY-000, STORY-001

**Evaluation Modules (Sequential, Each Depends on STORY-000 and STORY-002):**

- **STORY-003: Traditional Metrics Calculator**
  - Calculate execution time, success rate, coordination quality
  - JSON output format
  - Deterministic results with seed configuration
  - Requires: STORY-000, STORY-002

- **STORY-004: LLM Judge Evaluator**
  - Evaluate semantic quality using PydanticAI judge agent
  - Compare against human baseline reviews
  - Structured reasoning output with scores
  - Requires: STORY-000, STORY-002

- **STORY-005: Graph Complexity Analyzer**
  - Model agent interactions as NetworkX graphs
  - Calculate complexity metrics (density, centrality, clustering)
  - Export GraphML/JSON format
  - Requires: STORY-000

**Integration Layer (Requires All Evaluation Modules):**

- **STORY-006: Evaluation Pipeline Orchestrator**
  - Orchestrate evaluation modules in sequence
  - Handle module dependencies
  - Seed-based reproducibility
  - Requires: STORY-003, STORY-004, STORY-005

- **STORY-007: Consolidated Reporting & Observability**
  - Combine results from all evaluation tiers
  - Generate unified JSON report
  - Integrate loguru console logging
  - Optional Logfire/Weave cloud export via configuration
  - Requires: STORY-006

### Story Dependencies

```text
STORY-000 (Foundation)
    ├─→ STORY-001 (Download)
    │       └─→ STORY-002 (Load/Parse)
    │               ├─→ STORY-003 (Traditional Metrics)
    │               └─→ STORY-004 (LLM Judge)
    └─→ STORY-005 (Graph Analysis)

STORY-003 + STORY-004 + STORY-005
    └─→ STORY-006 (Pipeline)
            └─→ STORY-007 (Reporting)
```

**Note**: While STORY-003, STORY-004, and STORY-005 could theoretically run in
parallel, this breakdown maintains sequential execution for simplicity. See
README.md TODO for future parallel optimization.
