# frozen_string_literal: true

module Guests
  class GuestsController < ApplicationController
    def index
      xen_guests  = Xen::GuestLister.list
      xen_by_name = xen_guests.index_by(&:name)
      db_names    = Guest.pluck(:xen_name)

      # All known names: DB-registered (authoritative) + any running guest not yet in DB.
      all_names = (db_names + xen_by_name.keys).uniq

      @guests = all_names.map do |name|
        xen    = xen_by_name[name]
        config = Xen::Properties.read_config(name) || {}
        {
          name:       name,
          running:    xen.present?,
          vcpus:      xen&.vcpus   || config[:vcpus],
          memory:     xen&.memory  || config[:memory],
          state:      xen&.state,
          cpu_time:   xen&.time,
          disk:       config[:disk],
          vif_bridge: config[:vif_bridge]
        }
      end
    end

    def show
      @xen_guest = Xen::GuestLister.list.find { |g| g.name == params[:name] }
      @db_guest  = Guest.find_by(xen_name: params[:name])

      unless @xen_guest || @db_guest
        redirect_to guests_path, alert: "Guest '#{params[:name]}' not found."
        return
      end

      @config = Xen::Properties.read_config(params[:name]) || {}
    end
  end
end
