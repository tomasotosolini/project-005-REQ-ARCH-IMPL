# Project description

This software is a ruby-on-rails application that runs inside dom0 and manages the local Xen host.
The application has an administration area for managing users.
Application users are independent of dom0 system users.
Authentication is password-based, and users have distinct roles and entitlements.
Roles are hardcoded in the application (not user-configurable).
Every user must have a role assigned.
Role definitions and their entitlements will be specified later.
Allows to create/destroy/start/stop/monitor Xen guests (except dom0), and modify a fixed subset of guest properties: CPU, memory, disk, and network configuration.
This is intentionally a simplified management interface. Monitoring covers basic guest status (running/stopped) and real-time CPU and memory usage.

## Entitlements

List of grants:

    - (CREATOR) create/destroy vm
    - (ACTIVATOR) start/stop vm
    - (MONITOR) display vm status
    - (EDITOR) modify vm config

## Roles

List of roles:

    - guest - MONITOR
    - user - MONITOR + ACTIVATOR
    - admin - CREATOR + EDITOR + MONITOR + ACTIVATOR
