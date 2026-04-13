# frozen_string_literal: true

module Xen
  # Represents a single row from `xl list` output.
  GuestRecord = Struct.new(:name, :id, :memory, :vcpus, :state, :time, keyword_init: true)
end
