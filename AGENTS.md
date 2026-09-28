# PlotlyBaseExtras agent instructions

AI coding agents help with the development of this package. A human maintainer reviews every
change before it merges. This file and `CLAUDE.md` are the instructions for those agents.

## Tracked and local files

- Tracked: `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `docs/agents/` and `docs/adr/`.
- Local only: `.scratch/` holds specs, tickets and drafts. It is excluded in
  `.git/info/exclude`, so do not link to it from tracked files.

## Changelog

- A PR with a change that users can see adds its entry under `## [Unreleased]` in
  `CHANGELOG.md`. Use the Keep a Changelog categories: Added, Changed, Deprecated, Removed, Fixed,
  Security.
- At a release, the section of that version is the release text. It is the file for
  `gh release create vX.Y.Z --notes-file`, and the release notes of the Registrator comment in
  General.

## Agent skills

### Issue tracker

Issues are local markdown files under `.scratch/<feature-slug>/`, not GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels, written as a `Status:` line in each issue file. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
