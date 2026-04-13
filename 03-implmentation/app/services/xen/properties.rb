# frozen_string_literal: true

module Xen
  # Adjusts guest properties via xl commands.
  #
  # vcpu_set and mem_set apply changes to a running guest immediately.
  # Disk and network changes are not yet supported.
  # update_config rewrites the xl config file so changes persist across restarts.
  class Properties
    # Sets the number of vCPUs on a running guest.
    def self.vcpu_set(name, vcpus)
      Executor.run("xl", "vcpu-set", name, vcpus.to_s)
    end

    # Sets the memory allocation (in MiB) on a running guest.
    def self.mem_set(name, mib)
      Executor.run("xl", "mem-set", name, mib.to_s)
    end

    # Rewrites the xl config file with new vcpus and memory values.
    # This persists the changes so they take effect on the next start (or restart).
    def self.update_config(name, vcpus:, memory:)
      path = Xen::Lifecycle.config_path(name)
      raise Xen::CommandError.new(
        "config file not found for '#{name}'",
        stdout: "", stderr: "no config at #{path}"
      ) unless File.exist?(path)

      File.write(path, Xen::Lifecycle.generate_config(name: name, memory: memory, vcpus: vcpus))
    end

    # Reads vcpus and memory from the xl config file for a given guest name.
    # Returns a hash with :vcpus and :memory keys, or nil if no config file exists.
    def self.read_config(name)
      path = Xen::Lifecycle.config_path(name)
      return nil unless File.exist?(path)

      text   = File.read(path)
      vcpus  = text[/^vcpus\s*=\s*(\d+)/, 1]&.to_i
      memory = text[/^memory\s*=\s*(\d+)/, 1]&.to_i
      { vcpus: vcpus, memory: memory }
    end
  end
end
