# Implementation — Claude's Notes

Working notes on the implementation layer: patterns in use, non-obvious choices, known gotchas, and anything worth remembering across sessions.

## Changes history (RECENT)

### 2026-04-14 — Seed data / initial admin user

- `db/seeds.rb` — uses `find_or_create_by!` to create `admin@localhost` with role `admin` and password `changeme`. Fully idempotent; safe to re-run in any environment.
- No model or migration changes required.
- Suite: 169 examples, 0 failures.

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


