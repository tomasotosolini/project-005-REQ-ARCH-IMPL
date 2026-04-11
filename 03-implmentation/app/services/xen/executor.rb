# frozen_string_literal: true

require "open3"

module Xen
  class CommandError < StandardError
    attr_reader :stdout, :stderr

    def initialize(message, stdout:, stderr:)
      super(message)
      @stdout = stdout
      @stderr = stderr
    end
  end

  # Runs xl commands via Open3. Commands are always passed as an array — never
  # interpolated into a shell string — to prevent injection.
  #
  #   Xen::Executor.run("xl", "list")
  #   # => { stdout: "...", stderr: "", success: true }
  #
  # Raises Xen::CommandError if the command exits non-zero.
  class Executor
    def self.run(cmd, *args)
      stdout, stderr, status = Open3.capture3(cmd, *args)
      unless status.success?
        raise CommandError.new(
          "#{cmd} exited with status #{status.exitstatus}",
          stdout: stdout,
          stderr: stderr
        )
      end
      { stdout: stdout, stderr: stderr, success: true }
    end
  end
end
