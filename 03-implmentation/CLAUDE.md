# Implementation — Claude's Notes

Working notes on the implementation layer: patterns in use, non-obvious choices, known gotchas, and anything worth remembering across sessions.

## Changes history (RECENT)

### 2026-04-14 — Role-based entitlements with grant system

- `app/models/user.rb` — ROLES updated to `guest/user/admin`; added `GRANTS` (`:creator`, `:activator`, `:monitor`, `:editor`) and `ROLE_GRANTS` mapping; `has_grant?` method added.
- `app/controllers/application_controller.rb` — `require_role` replaced by `require_grant(grant)`, redirects to `root_path` on denial.
- `app/controllers/guests/lifecycle_controller.rb` — per-action guards: `:creator` on new/create/destroy, `:activator` on start/stop.
- `app/controllers/guests/properties_controller.rb` — guarded by `:editor`.
- `app/controllers/admin/users_controller.rb` — guarded by `:creator`; `require_admin` private method removed.
- Views — `index`, `show`, `application` layout conditionally render actions/links via `has_grant?`.
- Specs updated throughout: `:viewer`/`operator` traits/roles replaced, redirect expectations updated to `root_path`.
- Suite: 173 examples, 0 failures.

### 2026-04-14 — Seed data / initial admin user

- `db/seeds.rb` — uses `find_or_create_by!` to create `admin@localhost` with role `admin` and password `changeme`. Fully idempotent; safe to re-run in any environment.
- No model or migration changes required.
- Suite: 169 examples, 0 failures.



