# Implementation — Claude's Notes

Working notes on the implementation layer: patterns in use, non-obvious choices, known gotchas, and anything worth remembering across sessions.

## Changes history (RECENT)

### 2026-04-14 — Session expiry

- `config/initializers/session_store.rb` — explicit `:cookie_store` with `expire_after` (default 8h, env `SESSION_ABSOLUTE_TTL_HOURS`), `same_site: :lax`, `secure: true` in production only.
- `ApplicationController#enforce_session_idle_timeout` — before-action; checks `session[:last_seen_at]` on every authenticated request. Calls `reset_session` and redirects to `login_path` if idle window exceeded (default 30 min, env `SESSION_IDLE_TIMEOUT_MINUTES`). Updates `last_seen_at` on every passing request.
- `spec/rails_helper.rb` — added `config.include ActiveSupport::Testing::TimeHelpers` (required for `travel_to` / `freeze_time` in request specs).
- 3 new examples in `sessions_spec.rb`: within-window access, idle expiry via `travel_to`, `last_seen_at` stamp via `freeze_time`.
- Suite: 152 examples, 0 failures.

### 2026-04-13 — Admin area (user CRUD)

- `Admin::UsersController` — index, new/create, edit/update, destroy. Scoped under `namespace :admin`.
- `require_admin` before-action calls the existing `require_role(:admin)` helper — non-admin users are redirected to `login_path` with an alert.
- Destroy guard: admin cannot delete their own account (checked against `current_user`); shows an alert and redirects to the index.
- Password on edit: `update_params` strips blank `password` / `password_confirmation` keys so the digest is not overwritten when the admin leaves the fields empty.
- Nav: "Admin" link added to the layout, visible only when `current_user.admin?`.
- Suite: 147 examples, 0 failures.
