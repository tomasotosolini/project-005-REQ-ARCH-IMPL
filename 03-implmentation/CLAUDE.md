# Implementation — Claude's Notes

Working notes on the implementation layer: patterns in use, non-obvious choices, known gotchas, and anything worth remembering across sessions.

## Changes history (RECENT)

### 2026-04-14 — Disk and network property configuration

- `app/services/xen/lifecycle.rb` — `generate_config` and `create` now accept optional `disk:` (full xl spec, e.g. `phy:/dev/vg0/name,xvda,rw`) and `vif_bridge:` (bridge name). Lines are only emitted when the values are present.
- `app/services/xen/properties.rb` — `update_config` extended with `disk:` and `vif_bridge:` kwargs; `read_config` now parses both from the config file and returns them alongside vcpus/memory.
- `app/jobs/guest_operation_job.rb` — `perform` accepts `disk:` and `vif_bridge:` and forwards them to `Xen::Lifecycle.create`.
- `app/controllers/guests/lifecycle_controller.rb` — `create` extracts `disk` and `vif_bridge` params and passes them to the job.
- `app/controllers/guests/properties_controller.rb` — `load_guest` reads disk/vif from config (always, since xl list doesn't expose them); `update` enforces a stopped-only guard when disk or vif_bridge values change.
- `app/views/guests/lifecycle/new.html.erb` — added disk spec and vif bridge fields (both optional).
- `app/views/guests/properties/edit.html.erb` — added disk and vif_bridge fields; fields are HTML-disabled and labeled "Stop guest to change" when the guest is running.
- Specs updated: `properties_spec.rb` (read_config stub extended, new running-guard and stopped-change examples), `lifecycle_spec.rb` (create job matcher updated, disk/vif example added), `guest_operation_job_spec.rb` (create expectation updated, disk/vif passthrough example added).
- Suite: 169 examples, 0 failures.

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


