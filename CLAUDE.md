# Clarity

Flutter weather app — Clean Architecture, BLoC, Firebase, dartz, GetIt.

## ⚠️ START HERE — read `HANDOFF.md` first

`HANDOFF.md` is the live session-handoff doc: current state, what's pending, what's
blocked on the user, decisions already made (don't relitigate), and hard-won gotchas
(graph quirks, emulator quirks, build landmines already fixed). Reading it first will
save you hours. Keep it updated as work progresses.

Depth order: `HANDOFF.md` (state) → `AGENTS.md` (graph tooling) → `CLAUDE_MEMORY.md` (architecture).

## Code Review Graph

This project has a knowledge graph (`code-review-graph`) that indexes every Dart file.

**Always use the graph MCP tools before Grep/Glob/Read.** See `AGENTS.md` for the full tool reference, query recipes, and architecture map.

Quick start:
- `semantic_search_nodes_tool(query="WeatherBloc")` — find by name
- `query_graph_tool(pattern="callers_of", target="getWeather")` — who calls this
- `get_impact_radius_tool(changed_files=[...])` — blast radius
- `detect_changes_tool()` — risk-scored review of current changes

> **If the MCP tools aren't available** (they only load when a session starts *after*
> `.mcp.json` exists), don't fall back to Grep — the CLI has an exact equivalent for
> every tool: `code-review-graph search | query | impact | communities | architecture |
> detect-changes | dead-code`. Both read the same `graph.db`. See `HANDOFF.md` §3 for
> the Dart-specific query traps (notably: `callees_of` needs a **file path**, not a class).

## Architecture

- `lib/core/` — shared infra (DI, theme, errors, services, router)
- `lib/features/` — feature-first: auth, navigation, settings, weather
- Layer flow: `presentation → domain ← data`
- Error handling: `Either<Failure, T>` everywhere
- DI: `sl` (GetIt) in `injection_container.dart`

## Skills

Load `clarity-architecture` first when writing or reviewing Dart code. See `AGENTS.md` for the full skills list.

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool` instead of Grep
- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports
- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files
- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context_tool` | Need source snippets for review — token-efficient |
| `get_impact_radius_tool` | Understanding blast radius of a change |
| `get_affected_flows_tool` | Finding which execution paths are impacted |
| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |
| `get_architecture_overview_tool` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes_tool` for code review.
3. Use `get_affected_flows_tool` to understand impact.
4. Use `query_graph_tool` pattern="tests_for" to check coverage.
