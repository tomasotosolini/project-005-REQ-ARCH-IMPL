# frozen_string_literal: true

module Guests
  class PropertiesController < ApplicationController
    before_action :load_guest

    def edit
    end

    def update
      vcpus  = params[:vcpus].to_i
      memory = params[:memory].to_i

      if vcpus < 1
        flash.now[:alert] = "vCPUs must be at least 1."
        return render :edit, status: :unprocessable_entity
      end

      if memory < 16
        flash.now[:alert] = "Memory must be at least 16 MiB."
        return render :edit, status: :unprocessable_entity
      end

      if @running
        Xen::Properties.vcpu_set(@name, vcpus)
        Xen::Properties.mem_set(@name, memory)
      end

      Xen::Properties.update_config(@name, vcpus: vcpus, memory: memory)
      redirect_to guest_path(@name), notice: "Properties updated for '#{@name}'."
    rescue Xen::CommandError => e
      flash.now[:alert] = "Could not update properties: #{e.stderr.presence || e.message}"
      render :edit, status: :unprocessable_entity
    end

    private

    def load_guest
      @name      = params[:name]
      @xen_guest = Xen::GuestLister.list.find { |g| g.name == @name }
      @db_guest  = Guest.find_by(xen_name: @name)
      @running   = @xen_guest.present?

      # Current values: prefer live Xen data, fall back to config file.
      if @xen_guest
        @current_vcpus  = @xen_guest.vcpus
        @current_memory = @xen_guest.memory
      else
        config = Xen::Properties.read_config(@name)
        @current_vcpus  = config&.dig(:vcpus)
        @current_memory = config&.dig(:memory)
      end

      unless @xen_guest || @db_guest
        redirect_to guests_path, alert: "Guest '#{@name}' not found."
      end
    end
  end
end
