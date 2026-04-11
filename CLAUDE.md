# Project Conventions

## Structure

This project is organized into three layers, each in its own directory. The `XX-` numeric prefixes are visual ordering aids only — they carry no semantic meaning.

```
01-requirements/   — what the system must do
02-architecture/   — how the system is structured to do it
03-implmentation/  — the actual implementation
```

## Ownership

| Layer | Author | Reviewer/Reviser |
|---|---|---|
| Requirements | User | Claude (assists with representation) |
| Architecture | Claude | User |
| Implementation | Claude | User |

## Derivation Chain

Requirements → Architecture → Implementation

- Architecture is derived from requirements: it describes a system capable of satisfying them.
- Implementation is derived from architecture.
- When requirements change, architecture must be updated to stay in sync. When architecture changes, implementation follows.
- This is a living chain. No layer should drift out of sync with its upstream.

## Roles in Practice

- **Requirements**: the user is the authoritative source of intent and content. Claude assists in reviewing and refining how requirements are expressed — clarity, consistency, completeness — without altering the underlying intent.
- **Architecture**: Claude writes, drawing from the current state of requirements. The user reviews and revises as needed.
- **Implementation**: Claude writes, drawing from the current state of architecture. The user reviews and revises as needed.

## Per-Layer Findings Files

Each layer directory contains two companion files:

- `CLAUDE.md` — Claude's working notes for that layer: decisions, rationale, open questions, constraints. Claude writes and updates this freely.
- `USER.md` — User's findings and intent for that layer. Claude treats this as read-only: suggestions are offered as text, never applied silently.

**Session instruction:** At the start of each session, read the `USER.md` in every layer directory that is relevant to the current task, in addition to the `CLAUDE.md` files that are auto-loaded.
