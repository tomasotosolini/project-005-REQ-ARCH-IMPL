# frozen_string_literal: true

module Guests
  # Streams live guest stats as Server-Sent Events using Turbo Streams.
  # Each poll replaces the #guest-monitor element on the show page.
  #
  # The stream runs until the client disconnects (browser navigates away or
  # closes the tab). IOError / ClientDisconnected are expected and handled
  # silently.
  class MonitorController < ApplicationController
    include ActionController::Live

    POLL_INTERVAL = Integer(ENV.fetch("MONITOR_POLL_INTERVAL", 5))

    def stream
      response.headers["Content-Type"]  = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"

      name = params[:name]

      loop do
        guest   = Xen::Monitor.snapshot(name)
        pending = Guest.find_by(xen_name: name)&.pending_operation
        html    = render_to_string(
          partial: "guests/guests/monitor_panel",
          locals:  { guest: guest, name: name, pending: pending }
        )
        turbo = %(<turbo-stream action="replace" target="guest-monitor">)
        turbo << "<template>#{html}</template></turbo-stream>"

        response.stream.write("data: #{turbo}\n\n")
        sleep POLL_INTERVAL
      end
    rescue ActionController::Live::ClientDisconnected, IOError
      # Client gone — exit cleanly.
    ensure
      response.stream.close
    end
  end
end
