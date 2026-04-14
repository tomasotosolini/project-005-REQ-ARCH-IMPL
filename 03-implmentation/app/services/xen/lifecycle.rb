# frozen_string_literal: true

require "fileutils"

module Xen
  class Lifecycle
    # Config directory for generated xl config files.
    # In development, defaults to tmp/fake-xen/configs so no root access is needed.
    # Override with XEN_CONFIG_DIR in production (e.g. /etc/xen/managed).
    CONFIG_DIR = ENV.fetch("XEN_CONFIG_DIR") do
      Rails.env.development? ? Rails.root.join("tmp/fake-xen/configs").to_s : "/etc/xen/managed"
    end

    def self.config_path(name)
      File.join(CONFIG_DIR, "#{name}.cfg")
    end

    # Writes a config file and starts the guest. Returns the config file path.
    def self.create(name:, memory:, vcpus:, disk: nil, vif_bridge: nil)
      FileUtils.mkdir_p(CONFIG_DIR)
      path = config_path(name)
      File.write(path, generate_config(name: name, memory: memory, vcpus: vcpus,
                                       disk: disk, vif_bridge: vif_bridge))
      Executor.run("xl", "create", path)
      path
    end

    # Starts a stopped guest using its existing config file.
    def self.start(name)
      Executor.run("xl", "create", config_path(name))
    end

    # Gracefully shuts down a running guest.
    def self.stop(name)
      Executor.run("xl", "shutdown", name)
    end

    # Forcibly destroys a guest and removes its config file.
    # If xl reports the domain does not exist (already stopped), the error is
    # suppressed so that config and DB cleanup still proceeds.
    def self.destroy(name)
      begin
        Executor.run("xl", "destroy", name)
      rescue Xen::CommandError => e
        raise unless e.stderr.include?("does not exist")
      end
      path = config_path(name)
      File.delete(path) if File.exist?(path)
    end

    def self.generate_config(name:, memory:, vcpus:, disk: nil, vif_bridge: nil)
      lines = []
      lines << %(name   = "#{name}")
      lines << "memory = #{memory}"
      lines << "vcpus  = #{vcpus}"
      lines << "disk   = ['#{disk}']"            if disk.present?
      lines << "vif    = ['bridge=#{vif_bridge}']" if vif_bridge.present?
      lines.join("\n") + "\n"
    end
  end
end
