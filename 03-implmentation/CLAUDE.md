# Implementation — Claude's Notes

Working notes on the implementation layer: patterns in use, non-obvious choices, known gotchas, and anything worth remembering across sessions.

<!-- Add entries below. Most recent first. -->

## 2026-04-12 — Authentication

- `ApplicationController`: `require_login` before_action (redirects to `login_path`), `current_user` (session[:user_id] → User lookup), `logged_in?`, and `require_role(*roles)` helper. Both `current_user` and `logged_in?` are exposed as `helper_method`.
- `SessionsController`: skips `require_login`. `create` looks up by downcased email and calls `authenticate`; sets `session[:user_id]` on success. `destroy` deletes the session key and redirects to login.
- `User` model: added `before_save { self.email = email.downcase }` to normalize stored emails. Consistent with the case-insensitive uniqueness validation already in place.
- Routes: `GET /login` → `sessions#new`, `POST /login` → `sessions#create`, `DELETE /logout` → `sessions#destroy`. Root temporarily set to `sessions#new`; will be replaced by `guests#index`.
- Spec: `spec/requests/sessions_spec.rb` — covers login form render, successful login, case-insensitive email, bad password, unknown email, and logout. Factory note: overriding only `password` without also overriding `password_confirmation` causes `RecordInvalid`; use the factory's default password (`"password123"`) in the request spec.
- `require_login` will be tested end-to-end once the first non-session protected route (guests#index) exists. The root route currently maps to `sessions#new` which skips `require_login`, so it can't serve as the redirect target test.
- Suite: 74 examples, 0 failures.

## 2026-04-11 — Rails scaffold + models

- Rails 7.2.3.1 scaffolded with `rails new . --name=xen_manager --database=sqlite3 --skip-test --skip-bundle`.
- Directory name (`03-implmentation`) starts with a digit — `--name=xen_manager` is required; without it `rails new` exits with "Invalid application name".
- `rails new` creates a nested `.git` — must be removed immediately (`rm -rf .git`) to avoid a submodule situation.
- `spec/spec_helper.rb` was overwritten by `rails generate rspec:install`; the generated version is a superset so no content was lost.
- `User` model: `has_secure_password` (bcrypt), ROLES constant `%w[admin operator viewer]`, email uniqueness (case-insensitive), email format, role inclusion, `#admin?` helper.
- `Guest` model: `xen_name` uniqueness + format (`/\A[a-zA-Z0-9_\-]+\z/`). No state stored — Xen is authoritative.
- FactoryBot used for model specs; factories in `spec/factories/`. `bundler3.1 exec` works freely; new gem installs require user to run bundler (no write perms to `/var/lib/gems/`).
- Full suite: 67 examples (51 fake xl + 16 model), 0 failures.

## 2026-04-11 — Dev environment: fake xl

- Chose emulated xl over real Xen for development, even though Xen is present on the host. Reason: isolation, reproducibility, no risk of affecting real guests during dev.
- `Xen::Executor` is the single seam — no branching needed in application code. PATH override is sufficient.
- `bin/fake_xl` is a Ruby script (not shell) to keep config parsing and state I/O straightforward.
- State is a JSON file under `tmp/fake-xen/`. Writes are atomic (pid-suffixed temp + rename) to handle concurrent SSE polling.
- Stopped guests are retained in the state array (not deleted) so metadata survives lifecycle cycles — mirrors real Xen where the config file outlives the domain.
- `Time(s)` in `xl list` output is randomized on each call; realistic enough for the monitoring view.
- Reference document: `dev/fake-xl.md`

## 2026-04-11 — fake xl test suite

- Test framework: RSpec (chosen before Rails is set up; will integrate into the Rails app's Gemfile and `rails_helper` when created).
- Strategy: subprocess testing — each example invokes `bin/fake_xl` via `Open3.capture3` with `FAKE_XEN_STATE` pointing to a per-example temp directory. Tests the actual binary end-to-end, including stdout format, exit codes, and state file mutations.
- No mocks inside the spec — state is set up by writing JSON directly and read back for assertions.
- xl config files for `create` tests are written to the same temp directory and cleaned up in `after`.
- Tests do NOT cover the SSE polling loop or the Rails application layer — those will stub `Xen::Executor.run` directly.
- Spec: `spec/bin/fake_xl_spec.rb` (requires only `spec_helper`, not `rails_helper`).
- To run: `bundle install && bundle exec rspec spec/bin/fake_xl_spec.rb` (requires Ruby to be installed first).
