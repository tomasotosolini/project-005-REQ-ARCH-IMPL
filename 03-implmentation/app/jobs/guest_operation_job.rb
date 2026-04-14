# frozen_string_literal: true

# Executes a Xen lifecycle operation asynchronously.
#
# Supported operations: "start", "stop", "create", "destroy"
#
# For "create", pass memory: and vcpus: keyword arguments.
# On completion (success or failure) the pending_operation column is cleared
# so the monitor stream reflects the final state.
class GuestOperationJob < ApplicationJob
  queue_as :default

  # @param xen_name [String]
  # @param operation [String] one of "start", "stop", "create", "destroy"
  # @param memory [Integer] required for "create"
  # @param vcpus  [Integer] required for "create"
  def perform(xen_name, operation, memory: nil, vcpus: nil)
    case operation
    when "create"
      Xen::Lifecycle.create(name: xen_name, memory: memory.to_i, vcpus: vcpus.to_i)
    when "start"
      Xen::Lifecycle.start(xen_name)
    when "stop"
      Xen::Lifecycle.stop(xen_name)
    when "destroy"
      Xen::Lifecycle.destroy(xen_name)
      Guest.find_by(xen_name: xen_name)&.destroy
    else
      raise ArgumentError, "Unknown operation: #{operation}"
    end
  rescue Xen::CommandError => e
    Rails.logger.error("[GuestOperationJob] #{operation} #{xen_name} failed: #{e.message}")
    raise
  ensure
    # Clear the pending flag regardless of outcome so the UI updates.
    # For destroy the record may already be gone — guard with &.
    Guest.find_by(xen_name: xen_name)&.update_columns(pending_operation: nil)
  end
end
