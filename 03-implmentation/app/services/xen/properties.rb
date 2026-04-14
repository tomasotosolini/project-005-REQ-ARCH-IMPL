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

    # Rewrites the xl config file with new values.
    # disk and vif_bridge may only be changed when the guest is stopped;
    # the controller is responsible for enforcing this constraint before calling here.
    def self.update_config(name, vcpus:, memory:, disk: nil, vif_bridge: nil)
      path = Xen::Lifecycle.config_path(name)
      raise Xen::CommandError.new(
        "config file not found for '#{name}'",
        stdout: "", stderr: "no config at #{path}"
      ) unless File.exist?(path)

      File.write(path, Xen::Lifecycle.generate_config(
        name: name, memory: memory, vcpus: vcpus,
        disk: disk, vif_bridge: vif_bridge
      ))
    end

    # Reads vcpus, memory, disk spec, and vif bridge from the xl config file.
    # Returns a hash or nil if no config file exists.
    def self.read_config(name)
      path = Xen::Lifecycle.config_path(name)
      return nil unless File.exist?(path)

      text       = File.read(path)
      vcpus      = text[/^vcpus\s*=\s*(\d+)/, 1]&.to_i
      memory     = text[/^memory\s*=\s*(\d+)/, 1]&.to_i
      # disk = ['phy:/dev/vg0/name,xvda,rw']  — capture inner spec
      disk       = text[/^disk\s*=\s*\['([^']+)'\]/, 1]
      # vif = ['bridge=xenbr0']  — capture bridge name only
      vif_bridge = text[/^vif\s*=\s*\[.*bridge=([^\s,'\]]+)/, 1]
      { vcpus: vcpus, memory: memory, disk: disk, vif_bridge: vif_bridge }
    end
  end
end
