# Implementation — Claude's Notes

Working notes on the implementation layer: patterns in use, non-obvious choices, known gotchas, and anything worth remembering across sessions.

## Changes history (LESS RECENT)

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

### 2026-04-13 — Guest monitor (SSE / Turbo Streams)

- `Xen::Monitor.snapshot(name)` — thin wrapper around `GuestLister.list`; returns the matching `GuestRecord` or nil when the guest is not running.
- `Xen::GuestRecord` extracted to its own file `xen/guest_record.rb` so Zeitwerk can autoload it by constant name. Previously defined inline in `guest_lister.rb` alongside the lister — fine at runtime but breaks view specs that reference the struct without first touching `GuestLister`.
- `Guests::MonitorController#stream` — `ActionController::Live` endpoint. Polls `Xen::Monitor.snapshot` every `POLL_INTERVAL` seconds (env-configurable, default 5). Emits a `text/event-stream` payload: each event is a `<turbo-stream action="replace" target="guest-monitor">` wrapping the rendered `_monitor_panel` partial.
- `_monitor_panel` partial — renders a stats table when a record is present, or a "not currently running" message when nil.
- Show page wired with `<turbo-stream-source src="...">` pointing at `monitor_guest_path(name)`. The `#guest-monitor` div is rendered server-side on page load (initial state) and then replaced live by the SSE stream.
- Route: `GET /guests/:name/monitor` → `guests/monitor#stream`, named `monitor_guest`.
- Testing strategy: `ActionController::Live` body chunks are not captured by Rack::Test (`response.body` returns `""`). Request spec covers auth redirect + `Content-Type` header only. Content rendering is covered by a dedicated view spec for `_monitor_panel`.
- Suite: 112 examples, 0 failures.

### 2026-04-13 — Guest lifecycle (create/start/stop/destroy)

- `Xen::Lifecycle` service: `create`, `start`, `stop`, `destroy`. `destroy` tolerates "does not exist" from xl (guest already stopped) so config + DB cleanup still runs.
- Config file location: `ENV["XEN_CONFIG_DIR"]`, defaulting to `tmp/fake-xen/configs` in development and `/etc/xen/managed` in production. No Procfile.dev change needed.
- Routes added: `GET /guests/new` (before `/:name` to avoid name clash), `POST /guests`, `POST /guests/:name/start`, `POST /guests/:name/stop`, `DELETE /guests/:name`. No second named route for DELETE — `guest_path(name)` with `method: :delete` suffices.
- Show page shows Stop + Destroy buttons when running; Start + Delete buttons when stopped. Both use `button_to` with `turbo_confirm` for destructive actions.
- `create` action uses `find_or_create_by!` so re-creating a previously deleted guest doesn't raise.
- Spec stubs `Xen::Lifecycle` at the service level (not `Executor`) — keeps controller specs clean without file system or xl dependency.
- Suite: 103 examples, 0 failures.

### 2026-04-12 — guests#show

- Route: `GET /guests/:name` using `:name` (Xen domain name) rather than a DB id — Xen is authoritative, not the DB.
- `show` finds the guest by scanning `GuestLister.list`; also looks up the `Guest` DB record. If neither exists, redirects to `guests_path` with an alert.
- Show page renders Xen data when the guest is running; shows "not currently running" when only a DB record exists (stopped guest that hasn't been deleted from DB).
- Index view links each guest name to its show page via `guest_path(guest.name)`.
- Suite: 82 examples, 0 failures.

### 2026-04-12 — Xen service layer + guests#index

- `Xen::Executor.run(cmd, *args)` — shells out via `Open3.capture3` using an explicit argument array (no shell interpolation). Raises `Xen::CommandError` (with stdout/stderr attached) on non-zero exit.
- `Xen::GuestRecord` — `Struct` with fields: `name, id, memory, vcpus, state, time`. Lives in `xen/guest_lister.rb` alongside the parser that populates it.
- `Xen::GuestLister.list` — calls `xl list`, parses tabular output, excludes `Domain-0`. `GuestLister.parse(output)` is the pure parsing path (used directly in tests via stubbed output).
- `Guests::GuestsController#index` — queries `GuestLister.list` for live Xen data; indexes `Guest.all` by `xen_name` for DB metadata lookup in the view.
- Root route now wired to `guests/guests#index` (was `home#index`). `HomeController` and its view remain on disk but are no longer routed.
- Stub pattern for tests: `allow(Xen::Executor).to receive(:run).with("xl", "list").and_return(...)` — avoids any dependency on xl being present. Added to both `guests_spec.rb` and `sessions_spec.rb` (root redirect now hits guests#index).
- Suite: 79 examples, 0 failures.

### 2026-04-12 — Login management (home controller + layout nav)

- `HomeController#index` — minimal authenticated landing page; inherits `require_login` from `ApplicationController`. Placeholder until `guests#index` is built.
- Root route now wired to `home#index` (was `sessions#new`). Unauthenticated GET / redirects to login.
- Layout: `<nav>` block renders current user email + logout button (`button_to logout_path, method: :delete`) when `logged_in?`. Hidden on the login page.
- `sessions#new` guard: redirects to root if already logged in — visiting `/login` while authenticated goes straight to the dashboard.
- Spec: `sessions_spec.rb` updated — added "redirects to root when already logged in", "re-login is possible after logout", and updated `require_login` block to assert the redirect (root is now protected).

### 2026-04-12 — Authentication

- `ApplicationController`: `require_login` before_action (redirects to `login_path`), `current_user` (session[:user_id] → User lookup), `logged_in?`, and `require_role(*roles)` helper. Both `current_user` and `logged_in?` are exposed as `helper_method`.
- `SessionsController`: skips `require_login`. `create` looks up by downcased email and calls `authenticate`; sets `session[:user_id]` on success. `destroy` deletes the session key and redirects to login.
- `User` model: added `before_save { self.email = email.downcase }` to normalize stored emails. Consistent with the case-insensitive uniqueness validation already in place.
- Routes: `GET /login` → `sessions#new`, `POST /login` → `sessions#create`, `DELETE /logout` → `sessions#destroy`. Root temporarily set to `sessions#new`; will be replaced by `guests#index`.
- Spec: `spec/requests/sessions_spec.rb` — covers login form render, successful login, case-insensitive email, bad password, unknown email, and logout. Factory note: overriding only `password` without also overriding `password_confirmation` causes `RecordInvalid`; use the factory's default password (`"password123"`) in the request spec.
- `require_login` will be tested end-to-end once the first non-session protected route (guests#index) exists. The root route currently maps to `sessions#new` which skips `require_login`, so it can't serve as the redirect target test.
- Suite: 74 examples, 0 failures.

### 2026-04-11 — Rails scaffold + models

- Rails 7.2.3.1 scaffolded with `rails new . --name=xen_manager --database=sqlite3 --skip-test --skip-bundle`.
- Directory name (`03-implmentation`) starts with a digit — `--name=xen_manager` is required; without it `rails new` exits with "Invalid application name".
- `rails new` creates a nested `.git` — must be removed immediately (`rm -rf .git`) to avoid a submodule situation.
- `spec/spec_helper.rb` was overwritten by `rails generate rspec:install`; the generated version is a superset so no content was lost.
- `User` model: `has_secure_password` (bcrypt), ROLES constant `%w[admin operator viewer]`, email uniqueness (case-insensitive), email format, role inclusion, `#admin?` helper.
- `Guest` model: `xen_name` uniqueness + format (`/\A[a-zA-Z0-9_\-]+\z/`). No state stored — Xen is authoritative.
- FactoryBot used for model specs; factories in `spec/factories/`. `bundler3.1 exec` works freely; new gem installs require user to run bundler (no write perms to `/var/lib/gems/`).
- Full suite: 67 examples (51 fake xl + 16 model), 0 failures.

### 2026-04-11 — Dev environment: fake xl

- Chose emulated xl over real Xen for development, even though Xen is present on the host. Reason: isolation, reproducibility, no risk of affecting real guests during dev.
- `Xen::Executor` is the single seam — no branching needed in application code. PATH override is sufficient.
- `bin/fake_xl` is a Ruby script (not shell) to keep config parsing and state I/O straightforward.
- State is a JSON file under `tmp/fake-xen/`. Writes are atomic (pid-suffixed temp + rename) to handle concurrent SSE polling.
- Stopped guests are retained in the state array (not deleted) so metadata survives lifecycle cycles — mirrors real Xen where the config file outlives the domain.
- `Time(s)` in `xl list` output is randomized on each call; realistic enough for the monitoring view.
- Reference document: `dev/fake-xl.md`

### 2026-04-11 — fake xl test suite

- Test framework: RSpec (chosen before Rails is set up; will integrate into the Rails app's Gemfile and `rails_helper` when created).
- Strategy: subprocess testing — each example invokes `bin/fake_xl` via `Open3.capture3` with `FAKE_XEN_STATE` pointing to a per-example temp directory. Tests the actual binary end-to-end, including stdout format, exit codes, and state file mutations.
- No mocks inside the spec — state is set up by writing JSON directly and read back for assertions.
- xl config files for `create` tests are written to the same temp directory and cleaned up in `after`.
- Tests do NOT cover the SSE polling loop or the Rails application layer — those will stub `Xen::Executor.run` directly.
- Spec: `spec/bin/fake_xl_spec.rb` (requires only `spec_helper`, not `rails_helper`).
- To run: `bundle install && bundle exec rspec spec/bin/fake_xl_spec.rb` (requires Ruby to be installed first).
