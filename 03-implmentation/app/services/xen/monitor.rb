# frozen_string_literal: true

module Xen
  # Polls xl list and returns a single guest's current record, or nil when the
  # guest is not running.
  class Monitor
    def self.snapshot(name)
      GuestLister.list.find { |g| g.name == name }
    end
  end
end
