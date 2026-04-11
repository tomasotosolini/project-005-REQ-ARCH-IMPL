# Fake xl — Development Reference

`bin/fake_xl` emulates the Xen `xl` CLI for local development. It replaces the real `xl` binary via a PATH override so the application runs without a Xen dom0 environment. No application code changes are required.

---

## How it works

`Xen::Executor` shells out to `xl` using `Open3.capture3`. In development, `bin/fake/` is prepended to PATH (via `Procfile.dev`) so that `xl` resolves to `bin/fake_xl` before any system binary.

`bin/fake/xl` is a symlink to `../fake_xl`.

Guest state is persisted in `tmp/fake-xen/state.json` and survives across requests and SSE polling cycles. The file is created automatically on first use; `tmp/` is gitignored by default in Rails apps.

---

## Supported commands

| Command | Behaviour |
|---|---|
| `xl list` | Prints header + dom0 row + all guests whose state is `running` |
| `xl create <config>` | Parses `name`, `vcpus`, `memory` from the xl config file; marks guest `running` |
| `xl shutdown <name>` | Marks guest `stopped` (graceful); exits silently on success |
| `xl destroy <name>` | Marks guest `stopped` (forced); exits silently on success |
| `xl vcpu-set <name> <n>` | Updates `vcpus` for a running guest |
| `xl mem-set <name> <mib>` | Updates `memory` (MiB) for a running guest |

All error paths write to stderr and exit 1, matching real xl behaviour.

---

## State file

**Location:** `tmp/fake-xen/state.json`
**Override:** set `FAKE_XEN_STATE` environment variable to any absolute path.

```json
{
  "guests": [
    { "name": "web-01",   "id": 1, "vcpus": 2, "memory": 2048, "state": "running" },
    { "name": "cache-01", "id": 3, "vcpus": 1, "memory": 1024, "state": "stopped" }
  ],
  "next_id": 4
}
```

`state` is either `"running"` or `"stopped"`. Only running guests appear in `xl list` output. Stopped guests are retained in the array so that their metadata (vcpus, memory) survives a shutdown/start cycle, matching real Xen semantics where the config file persists.

Writes use a pid-suffixed temp file + atomic rename so concurrent reads from the SSE polling loop never see a partial write.

---

## xl list output format

The output matches real xl list format so that `Xen::GuestLister` parses both without branching:

```
Name                                        ID   Mem VCPUs	State	Time(s)
Domain-0                                     0  1024     1	r-----	 12345.6
web-01                                       1  2048     2	-b----	   456.7
```

- dom0 is always present with state `r-----`.
- Running guests appear with state `-b----` (blocked/idle — typical for a guest not actively consuming CPU).
- `Time(s)` values are random on each call; this is sufficient for the monitoring view.

---

## PATH wiring

`Procfile.dev` prepends `bin/fake` to PATH for both processes:

```
web:    PATH=bin/fake:$PATH bin/rails server -p 3000
worker: PATH=bin/fake:$PATH bin/jobs
```

The real system `xl` (if present) is shadowed and never called during development.

---

## Rake tasks

```
rake fake_xen:reset   # wipe state — no guests
rake fake_xen:seed    # load sample guests: web-01 (running), db-01 (running), cache-01 (stopped)
rake fake_xen:status  # print current state to stdout
```

Run `rake fake_xen:seed` at the start of a dev session to have a populated guest list immediately.

---

## Tests

Tests stub `Xen::Executor.run` at the Ruby level — they do not use the fake binary. This keeps the test suite fast and free of filesystem side effects.

```ruby
# Example RSpec stub
allow(Xen::Executor).to receive(:run)
  .with("xl", "list")
  .and_return({ stdout: xl_list_fixture, stderr: "", success: true })
```

System tests (Capybara) may optionally wire the fake binary via `FAKE_XEN_STATE` pointing to a test-controlled fixture file, but direct executor stubbing is preferred for speed.

---

## Relation to real xl

The fake is designed to produce output that `Xen::GuestLister` can parse without any special-casing. If the real xl output format differs in practice (e.g., column spacing varies between xl versions), adjust `Xen::GuestLister`'s parser to be more lenient, then verify the fake still produces matching output.

The fake does not emulate: `xl info`, `xl console`, `xl dmesg`, or any other xl subcommand not used by the application. Adding a new xl command to the application requires a corresponding handler in `bin/fake_xl`.
