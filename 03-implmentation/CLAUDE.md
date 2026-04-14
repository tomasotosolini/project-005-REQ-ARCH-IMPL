# Implementation — Claude's Notes

Working notes on the implementation layer: patterns in use, non-obvious choices, known gotchas, and anything worth remembering across sessions.

## Changes history (RECENT)

### 2026-04-14 — GuestOperationJob (async lifecycle)

- `config/environments/development.rb` — `:async` queue adapter (background threads, no extra process).
- `config/environments/test.rb` — `:test` queue adapter; jobs are enqueued but not executed unless the spec calls `perform_enqueued_jobs`.
- `config/environments/production.rb` — `:solid_queue` adapter (set by `rails solid_queue:install`). `config/queue.yml`, `config/recurring.yml`, `db/queue_schema.rb` generated.
- `db/migrate/20260414054317_add_pending_operation_to_guests.rb` — adds `pending_operation` (nullable string) to `guests`.
- `app/jobs/guest_operation_job.rb` — wraps create/start/stop/destroy. Calls `Xen::Lifecycle` in background; clears `pending_operation` in `ensure` on success or failure; destroy also removes the DB record.
- `app/controllers/guests/lifecycle_controller.rb` — all actions now set `pending_operation` and enqueue `GuestOperationJob` instead of calling Xen synchronously.
- `app/controllers/guests/monitor_controller.rb` — loads `pending_operation` from DB on each poll tick and passes it to the partial.
- `app/views/guests/guests/_monitor_panel.html.erb` — shows "Operation in progress: <name>…" when `pending` is set.
- `spec/jobs/guest_operation_job_spec.rb` — new; 10 examples covering all operations, error re-raise, and ensure-cleanup.
- `spec/requests/guests/lifecycle_spec.rb` — rewritten; assertions now use `have_enqueued_job` instead of Xen stub expectations.
- `spec/views/guests/guests/monitor_panel_spec.rb` — updated to pass `pending:` local; added pending-notice example.
- Suite: 161 examples, 0 failures.

### 2026-04-14 — Session expiry

- `config/initializers/session_store.rb` — explicit `:cookie_store` with `expire_after` (default 8h, env `SESSION_ABSOLUTE_TTL_HOURS`), `same_site: :lax`, `secure: true` in production only.
- `ApplicationController#enforce_session_idle_timeout` — before-action; checks `session[:last_seen_at]` on every authenticated request. Calls `reset_session` and redirects to `login_path` if idle window exceeded (default 30 min, env `SESSION_IDLE_TIMEOUT_MINUTES`). Updates `last_seen_at` on every passing request.
- `spec/rails_helper.rb` — added `config.include ActiveSupport::Testing::TimeHelpers` (required for `travel_to` / `freeze_time` in request specs).
- 3 new examples in `sessions_spec.rb`: within-window access, idle expiry via `travel_to`, `last_seen_at` stamp via `freeze_time`.
- Suite: 152 examples, 0 failures.

