# frozen_string_literal: true

module Guests
  class GuestsController < ApplicationController
    def index
      @xen_guests = Xen::GuestLister.list
      # Index DB records by xen_name for O(1) metadata lookup in the view.
      @db_guests = Guest.all.index_by(&:xen_name)
    end
  end
end
