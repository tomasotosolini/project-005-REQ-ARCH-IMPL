# Architecture — Claude's Notes

Working notes on the architecture layer: design decisions, rejected alternatives, constraints that shaped the design, and anything worth remembering across sessions.

<!-- Add entries below. Most recent first. -->

## 2026-04-11 — Initial architecture created

- First architecture document written from `01-requirements/PROJECT.md`.
- Chose `xl` CLI over libvirt/Xen API: simplest approach in dom0, no extra daemon.
- Chose SQLite over PostgreSQL: single-host, no concurrent multi-node writes.
- Guest table is deliberately thin — Xen is authoritative for state; DB only holds app-level metadata.
- Monitoring via SSE + Turbo Streams (no WebSockets needed for read-only push).
- Long-running Xen ops dispatched to Solid Queue to avoid blocking puma.
- Role entitlements deferred — requirements don't define them yet. Open question recorded.
- Network/disk config scope is ambiguous in requirements. Conservative interpretation recorded as open question.
