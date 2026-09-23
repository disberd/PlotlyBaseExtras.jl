# PlotlyBaseExtras agent instructions

AI coding agents help with the development of this package. A human maintainer reviews every
change before it merges. This file and `CLAUDE.md` are the instructions for those agents.

## Tracked and local files

- Tracked: `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `docs/agents/` and `docs/adr/`.
- Local only: `.scratch/` holds specs, tickets and drafts. It is excluded in
  `.git/info/exclude`, so do not link to it from tracked files.

## Agent skills

### Issue tracker

Issues are local markdown files under `.scratch/<feature-slug>/`, not GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels, written as a `Status:` line in each issue file. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
