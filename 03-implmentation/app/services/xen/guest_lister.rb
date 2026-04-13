# frozen_string_literal: true

module Xen
  # Calls `xl list` and parses its tabular output into GuestRecord objects.
  # Domain-0 is excluded — it is infrastructure, not a managed guest.
  class GuestLister
    def self.list
      result = Executor.run("xl", "list")
      parse(result[:stdout])
    end

    def self.parse(output)
      lines = output.lines
      lines.shift  # discard header line

      lines.filter_map do |line|
        next if line.strip.empty?

        # xl list columns: Name ID Mem VCPUs State Time(s)
        # Columns are space-separated; state and time may be tab-separated from vcpus.
        parts = line.split
        next if parts[0] == "Domain-0"

        GuestRecord.new(
          name:   parts[0],
          id:     parts[1].to_i,
          memory: parts[2].to_i,
          vcpus:  parts[3].to_i,
          state:  parts[4],
          time:   parts[5].to_f
        )
      end
    end
  end
end
