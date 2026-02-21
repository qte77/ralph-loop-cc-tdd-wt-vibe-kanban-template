# CLI Name Candidates

The name should signal: BDD/TDD top-down enforcement, playful personality
(like `ralph`), and be available across GitHub, Go (pkg.go.dev), npm, and
PyPI. Research conducted February 2025.

## Shortlisted (zero conflicts across all ecosystems)

| Name | Chars | Example CLI | Signal | Pros | Cons |
|------|-------|-------------|--------|------|------|
| `ought` | 5 | `ought run`, `ought status` | BDD "should" in archaic form | Directly evokes BDD obligation language; unique; pleasant to type; no conflicts anywhere | Archaic — some users may not immediately parse the meaning; doesn't scream "testing" |
| `shall` | 5 | `shall run`, `shall status` | RFC/requirements keyword ("the system shall...") | Universally recognized in requirements engineering; slightly pompous = playful; clean namespace | Could feel stiff; less personality than `ralph`/`wiggly` |
| `decree` | 6 | `decree run`, `decree status` | Top-down mandate, stories are decrees | Unmistakably top-down; fun authoritative tone; reads naturally as a CLI verb | 6 chars (longer to type); more "authority" than "testing" |
| `sworn` | 5 | `sworn run`, `sworn status` | Stories are sworn commitments | Strong contract metaphor; compact; pairs well with BDD ("sworn acceptance criteria") | Past tense feels slightly odd as a command name; less intuitive than `ought`/`shall` |
| `insist` | 6 | `insist run`, `insist status` | Won't accept anything less than green | Strong personality; immediately understood; BDD tone ("I insist this behavior holds") | [octo/insist](https://github.com/octo/insist) exists (Go CLI, retries commands); [insist on PyPI](https://pypi.org/project/insist/) (assertion lib, abandoned 2014) |

## Taglines and descriptions per candidate

### `ought`

- *"your stories ought to pass, and they will"*
- *"stories in, passing code out"*
- *"because acceptance criteria aren't suggestions"*
- ought reads your PRD, resolves story dependencies, spawns parallel
  worktrees, and won't stop until every acceptance criterion is green.
  Single binary, no runtime dependencies. Successor to Ralph Loop.

### `shall`

- *"from 'the system shall' to 'the system does'"*
- *"the system shall pass all acceptance criteria"*
- *"requirements-driven TDD enforcement for AI coding agents"*
- shall takes your requirements ("the system shall..."), resolves
  dependencies, and drives AI coding agents through parallel TDD loops
  until every story passes. Single Go binary, successor to Ralph Loop.

### `decree`

- *"stories are decrees, tests are the law"*
- *"your PRD has spoken"*
- *"top-down mandates, bottom-up proof"*
- decree treats every user story as a mandate: resolve dependencies,
  dispatch parallel workers, enforce TDD commits, accept nothing less
  than green. Single Go binary, successor to Ralph Loop.

### `sworn`

- *"acceptance criteria are sworn commitments"*
- *"stories sworn, tests proven"*
- *"bound by spec, verified by test"*
- sworn treats every story as a binding contract: schedule by dependency,
  drive TDD loops in parallel worktrees, verify acceptance criteria,
  refuse to merge until all commitments are met. Successor to Ralph Loop.

### `insist`

- *"we insist your tests pass"*
- *"relentless TDD enforcement for AI coding agents"*
- *"it won't stop until everything's green"*
- insist reads your PRD, resolves dependencies, and relentlessly drives
  AI coding agents through parallel TDD loops. It insists on
  red-before-green commits and won't merge until every acceptance
  criterion passes. Successor to Ralph Loop.

## Tagline-name fit ranking

| Rank | Name | Best tagline | Why it works |
|------|------|-------------|--------------|
| 1 | `shall` | "from 'the system shall' to 'the system does'" | Direct callback to requirements language everyone knows |
| 2 | `ought` | "your stories ought to pass, and they will" | Natural English, the name completes the sentence |
| 3 | `decree` | "stories are decrees, tests are the law" | Sets up the full metaphor in 8 words |
| 4 | `insist` | "we insist your tests pass" | Name is the verb, tagline is the action |
| 5 | `sworn` | "acceptance criteria are sworn commitments" | Strong but needs more words to land |

## Eliminated during research

| Name | Reason eliminated |
|------|-------------------|
| `wiggly` | Original codename; no technical signal; not immediately parseable |
| `nag` | [Crowded namespace](https://github.com/utensils/nag) — multiple Go packages, GitHub repos, similar concept ("mother-in-law of linters") |
| `grumble` | [Heavily taken in Go](https://github.com/desertbit/grumble) — CLI/shell framework, Mumble server, vuln scanner |
| `nudge` | [macadmins/nudge](https://github.com/macadmins/nudge) is popular; multiple Go projects |
| `stoplight` | [Stoplight.io](https://stoplight.io/) is a major API design platform with official CLI |
| `turnstile` | Dominated by Cloudflare Turnstile Go packages |
| `fable` | [fable-compiler/Fable](https://github.com/fable-compiler/Fable) has strong name recognition |
| `stickler` | [Stickler CI](https://github.com/stickler-ci) occupies the code review/linting space |
| `must` | [golang-must/must](https://pkg.go.dev/github.com/golang-must/must) — Go testing assertion library |
| `vow` | [dfilatov/vow](https://github.com/dfilatov/vow) on npm (88K weekly downloads); [vows.js](https://www.vowsjs.org/) BDD framework |
| `pledge` | `pledge` is an [OpenBSD syscall](https://github.com/golang/go/issues/60322) in Go's `x/sys/unix` — would confuse Go developers |
| `ergo` | [Heavily taken](https://github.com/ergo-services/ergo) — actor framework, reverse proxy, multiple Go projects |
| `gavel` | [gavel-tool](https://github.com/gavel-tool) GitHub org with Python packages |
| `cascade` | [thedeltaflyer/cascade](https://github.com/thedeltaflyer/cascade) — Go goroutine lifecycle manager |
| `nope` | Nearly clear but weak signal — says what fails, not the methodology |
| `bossy` | [bossy on npm](https://www.npmjs.com/package/bossy) (deprecated Hapi CLI parser); more "attitude" than "methodology" |
| `redgreen` | Clear namespace but too literal; no personality |
| `tattle` | Clear namespace but "reports on everything" doesn't convey top-down BDD |
| `hence` | Clear namespace but weakest personality of all candidates |
| `ralph` | Ancestor name; strong brand recognition within the project; but generic English name makes GitHub/pkg.go.dev discovery difficult and conflicts with unrelated projects |

## Decision

To be made before first release. Current recommendation:
**`ought`** — shortest, cleanest BDD signal, zero conflicts, pleasant
ergonomics. Whatever name is chosen, documentation should credit `ralph`
as the ancestor project (the bash engine that bootstrapped its own
replacement).
