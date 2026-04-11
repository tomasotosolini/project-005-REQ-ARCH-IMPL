# frozen_string_literal: true

module Guests
  class GuestsController < ApplicationController
    def index
      @xen_guests = Xen::GuestLister.list
      # Index DB records by xen_name for O(1) metadata lookup in the view.
      @db_guests = Guest.all.index_by(&:xen_name)
    end

    def show
      @xen_guest = Xen::GuestLister.list.find { |g| g.name == params[:name] }
      @db_guest  = Guest.find_by(xen_name: params[:name])

      unless @xen_guest || @db_guest
        redirect_to guests_path, alert: "Guest '#{params[:name]}' not found."
      end
    end
  end
end
