# frozen_string_literal: true

# Absolute cookie TTL: the browser discards the session cookie after this
# interval regardless of activity. Complements the idle timeout enforced
# in ApplicationController.
Rails.application.config.session_store(
  :cookie_store,
  key:          "_xen_manager_session",
  expire_after: ENV.fetch("SESSION_ABSOLUTE_TTL_HOURS", "8").to_i.hours,
  same_site:    :lax,
  secure:       Rails.env.production?
)
