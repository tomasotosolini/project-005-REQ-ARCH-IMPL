# Implementation — Claude's Notes

# Recent changes

## 2026-04-13 — Admin area (user CRUD)

- `Admin::UsersController` — index, new/create, edit/update, destroy. Scoped under `namespace :admin`.
- `require_admin` before-action calls the existing `require_role(:admin)` helper — non-admin users are redirected to `login_path` with an alert.
- Destroy guard: admin cannot delete their own account (checked against `current_user`); shows an alert and redirects to the index.
- Password on edit: `update_params` strips blank `password` / `password_confirmation` keys so the digest is not overwritten when the admin leaves the fields empty.
- Nav: "Admin" link added to the layout, visible only when `current_user.admin?`.
- Suite: 147 examples, 0 failures.

## 2026-04-13 — Guest monitor (SSE / Turbo Streams)

- `Xen::Monitor.snapshot(name)` — thin wrapper around `GuestLister.list`; returns the matching `GuestRecord` or nil when the guest is not running.
- `Xen::GuestRecord` extracted to its own file `xen/guest_record.rb` so Zeitwerk can autoload it by constant name. Previously defined inline in `guest_lister.rb` alongside the lister — fine at runtime but breaks view specs that reference the struct without first touching `GuestLister`.
- `Guests::MonitorController#stream` — `ActionController::Live` endpoint. Polls `Xen::Monitor.snapshot` every `POLL_INTERVAL` seconds (env-configurable, default 5). Emits a `text/event-stream` payload: each event is a `<turbo-stream action="replace" target="guest-monitor">` wrapping the rendered `_monitor_panel` partial.
- `_monitor_panel` partial — renders a stats table when a record is present, or a "not currently running" message when nil.
- Show page wired with `<turbo-stream-source src="...">` pointing at `monitor_guest_path(name)`. The `#guest-monitor` div is rendered server-side on page load (initial state) and then replaced live by the SSE stream.
- Route: `GET /guests/:name/monitor` → `guests/monitor#stream`, named `monitor_guest`.
- Testing strategy: `ActionController::Live` body chunks are not captured by Rack::Test (`response.body` returns `""`). Request spec covers auth redirect + `Content-Type` header only. Content rendering is covered by a dedicated view spec for `_monitor_panel`.
- Suite: 112 examples, 0 failures.
