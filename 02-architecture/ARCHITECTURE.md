# Architecture

Derived from: `01-requirements/PROJECT.md`

---

## Overview

A Ruby on Rails web application running in dom0 that provides a simplified management interface for the local Xen host. It handles user authentication with role-based access, and exposes guest lifecycle management (create/destroy/start/stop), property configuration (CPU, memory, disk, network), and real-time monitoring.

---

## Technology Stack

| Concern | Choice | Rationale |
|---|---|---|
| Framework | Ruby on Rails (latest stable) | Required by specification |
| Database | SQLite | Single-host deployment; no concurrent multi-node writes |
| Background jobs | Solid Queue | Rails default; no external broker dependency |
| Real-time push | Turbo Streams over SSE | Sufficient for monitoring; no full duplex needed |
| Frontend | Hotwire (Turbo + Stimulus) | Rails default; avoids a separate JS build pipeline |
| Xen interface | `xl` CLI via `Open3` | Direct, no extra daemon; xl is the standard tool in dom0 |
| Password hashing | `has_secure_password` (bcrypt) | Sufficient; avoids Devise dependency |

---

## Application Structure

```
app/
  controllers/
    admin/
      users_controller.rb       # user CRUD (admin-only)
    guests/
      guests_controller.rb      # list, show
      lifecycle_controller.rb   # create, destroy, start, stop
      properties_controller.rb  # CPU, memory, disk, network config
      monitor_controller.rb     # SSE stream for real-time status
    sessions_controller.rb      # login/logout
  models/
    user.rb
    guest.rb                    # thin record for metadata only
  services/
    xen/
      executor.rb               # runs xl commands, captures output/errors
      guest_lister.rb           # parses `xl list` output
      guest_info.rb             # parses per-guest detail
      lifecycle.rb              # create, destroy, start, stop
      properties.rb             # vcpus, memory, disk, network config
      monitor.rb                # status + cpu/mem usage
  jobs/
    guest_operation_job.rb      # wraps async Xen operations
```

---

## Data Model

### `users` table

| Column | Type | Notes |
|---|---|---|
| id | integer PK | |
| email | string | unique, required |
| password_digest | string | bcrypt via `has_secure_password` |
| role | string | validated against hardcoded role list |
| created_at / updated_at | datetime | |

Roles are a fixed enum defined in the `User` model. Role definitions and per-role entitlements will be added once specified in requirements.

### `guests` table

Xen is the authoritative source of truth for guest state. The `guests` table stores only application-level metadata that Xen does not track.

| Column | Type | Notes |
|---|---|---|
| id | integer PK | |
| xen_name | string | matches the xl domain name; unique |
| created_at / updated_at | datetime | |

Additional metadata columns (display name, notes, owner) may be added when the corresponding requirements are specified. No guest state (running/stopped, CPU, memory) is persisted — it is always read live from Xen.

---

## Authentication & Authorization

- Session-based authentication. Rails signed cookie session; no token/JWT.
- `has_secure_password` handles bcrypt hashing.
- `ApplicationController` enforces `require_login` before action on all controllers except `SessionsController`.
- Role checks are enforced at the controller level via a `require_role` helper. Roles are hardcoded constants in `User::ROLES`. Entitlement logic will be added once role definitions are provided.

---

## Xen Integration

All Xen operations go through `Xen::Executor`, which shells out using `Open3.capture3`. This keeps the interface explicit and auditable.

```ruby
# Xen::Executor.run(command, *args) → { stdout:, stderr:, success: }
Xen::Executor.run("xl", "list", "-l")
```

- Commands are constructed with an explicit array (never interpolated into a shell string) to prevent injection.
- Failed commands raise `Xen::CommandError` with stdout/stderr attached.
- Service objects in `Xen::` parse xl output and expose typed Ruby objects to controllers and jobs.

### Guest lifecycle

| Operation | xl command |
|---|---|
| List guests | `xl list` |
| Start | `xl create <config>` |
| Stop (graceful) | `xl shutdown <name>` |
| Stop (forced) | `xl destroy <name>` |
| Create | `xl create <config>` with a generated config file |
| Delete | destroy + remove config |

Guest creation generates a temporary xl config file from application parameters, then invokes `xl create`. Config files are stored under a dedicated directory (e.g. `/etc/xen/managed/`).

### Property modification

Some properties (CPU count, memory) can be adjusted on a running guest via `xl vcpu-set` and `xl mem-set`. Disk and network configuration changes require the guest to be stopped; the application enforces this check before applying.

---

## Guest Monitoring

### Status (running/stopped)

Derived from `xl list` output. Parsed by `Xen::GuestLister` on each request or polling cycle.

### Real-time CPU and memory usage

Delivered via Server-Sent Events (SSE) using a Rails streaming action in `Monitor::GuestController`. The stream polls `xl list` every N seconds (configurable, default 5 s) and pushes Turbo Stream fragments to update the monitoring panel in-place.

```
GET /guests/:name/monitor  → SSE stream
```

Long-running Xen operations (start, stop, create) are dispatched as `GuestOperationJob` via Solid Queue to avoid blocking the web process. The job updates a simple status field that the SSE stream can include in its next push.

---

## Admin Area

Scoped under `/admin`. Accessible only to users with the admin role (enforced by `require_role :admin`).

Covers:
- List, create, edit, deactivate users
- Assign and change roles

---

## Security Considerations

- All `xl` commands use array-form `Open3.capture3` — no shell interpolation.
- CSRF protection enabled (Rails default).
- Passwords never logged or serialized.
- Session expiry and secure cookie flags configured in production.
- The application runs as a dom0 user with sufficient privileges to run `xl`; it should run as a dedicated non-root user that is a member of the xen management group rather than as root.

---

## Open Questions

1. **Role definitions and entitlements** — not yet specified in requirements. Architecture assumes a simple `require_role` check per controller action; this will be refined once roles are defined.
2. **Guest creation workflow** — the set of configurable parameters at creation time is not yet specified. Assumed to be the same fixed subset (CPU, memory, disk, network) plus a name.
3. **Network configuration** — "network configuration" scope is unclear. Assumed to mean attaching/detaching virtual interfaces and selecting the bridge; not host-level network changes.
4. **Disk configuration** — assumed to mean resizing existing virtual disks or attaching/detaching block devices; not host storage pool management.
