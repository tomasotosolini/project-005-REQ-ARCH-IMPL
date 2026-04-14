# Implementation — Claude's Notes

Working notes on the implementation layer: patterns in use, non-obvious choices, known gotchas, and anything worth remembering across sessions.

## Changes history (RECENT)

### 2026-04-14 — Guest listing completeness

- `app/controllers/guests/guests_controller.rb` — `index` now builds a merged list of all known guests (DB-registered + any running but unregistered); calls `Xen::Properties.read_config` per guest to surface disk/vif_bridge. `show` also calls `read_config` and exposes `@config` to the view.
- `app/views/guests/guests/index.html.erb` — rewritten: shows all guests (running + stopped), Status column (running/stopped), CPU time column for running guests, Disk and VIF Bridge columns from config.
- `app/views/guests/guests/show.html.erb` — added config table rendering disk and vif_bridge when present.
- `spec/requests/guests/guests_spec.rb` — stubs `Xen::Properties.read_config`; added examples for stopped guests in index, config detail columns, CPU time, and disk/vif on show page.
- Suite: 178 examples, 0 failures.

### 2026-04-14 — Role-based entitlements with grant system

- `app/models/user.rb` — ROLES updated to `guest/user/admin`; added `GRANTS` (`:creator`, `:activator`, `:monitor`, `:editor`) and `ROLE_GRANTS` mapping; `has_grant?` method added.
- `app/controllers/application_controller.rb` — `require_role` replaced by `require_grant(grant)`, redirects to `root_path` on denial.
- `app/controllers/guests/lifecycle_controller.rb` — per-action guards: `:creator` on new/create/destroy, `:activator` on start/stop.
- `app/controllers/guests/properties_controller.rb` — guarded by `:editor`.
- `app/controllers/admin/users_controller.rb` — guarded by `:creator`; `require_admin` private method removed.
- Views — `index`, `show`, `application` layout conditionally render actions/links via `has_grant?`.
- Specs updated throughout: `:viewer`/`operator` traits/roles replaced, redirect expectations updated to `root_path`.
- Suite: 173 examples, 0 failures.


