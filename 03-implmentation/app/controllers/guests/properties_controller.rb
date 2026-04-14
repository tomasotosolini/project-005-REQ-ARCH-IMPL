# frozen_string_literal: true

module Guests
  class PropertiesController < ApplicationController
    before_action -> { require_role(:admin, :operator) }
    before_action :load_guest

    def edit
    end

    def update
      vcpus      = params[:vcpus].to_i
      memory     = params[:memory].to_i
      disk       = params[:disk].to_s.strip.presence
      vif_bridge = params[:vif_bridge].to_s.strip.presence

      if vcpus < 1
        flash.now[:alert] = "vCPUs must be at least 1."
        return render :edit, status: :unprocessable_entity
      end

      if memory < 16
        flash.now[:alert] = "Memory must be at least 16 MiB."
        return render :edit, status: :unprocessable_entity
      end

      # Disk and network changes are config-only and require the guest to be stopped.
      if @running && (disk != @current_disk || vif_bridge != @current_vif_bridge)
        flash.now[:alert] = "Disk and network can only be changed while the guest is stopped."
        return render :edit, status: :unprocessable_entity
      end

      if @running
        Xen::Properties.vcpu_set(@name, vcpus)
        Xen::Properties.mem_set(@name, memory)
      end

      Xen::Properties.update_config(@name, vcpus: vcpus, memory: memory,
                                    disk: disk, vif_bridge: vif_bridge)
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

      # CPU/memory: prefer live Xen data when running, fall back to config file.
      # Disk/network: always read from config file (Xen does not expose them via xl list).
      config = Xen::Properties.read_config(@name)

      if @xen_guest
        @current_vcpus  = @xen_guest.vcpus
        @current_memory = @xen_guest.memory
      else
        @current_vcpus  = config&.dig(:vcpus)
        @current_memory = config&.dig(:memory)
      end

      @current_disk       = config&.dig(:disk)
      @current_vif_bridge = config&.dig(:vif_bridge)

      unless @xen_guest || @db_guest
        redirect_to guests_path, alert: "Guest '#{@name}' not found."
      end
    end
  end
end
