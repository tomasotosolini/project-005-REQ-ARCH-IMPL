# frozen_string_literal: true

module Guests
  class LifecycleController < ApplicationController
    before_action -> { require_grant(:creator) },   only: %i[new create destroy]
    before_action -> { require_grant(:activator) },  only: %i[start stop]

    def new
    end

    def create
      name       = params[:name].to_s.strip
      memory     = params[:memory].to_i
      vcpus      = params[:vcpus].to_i
      disk       = params[:disk].to_s.strip.presence
      vif_bridge = params[:vif_bridge].to_s.strip.presence

      if name.blank?
        flash.now[:alert] = "Name is required."
        return render :new, status: :unprocessable_entity
      end

      guest = Guest.find_or_create_by!(xen_name: name)
      guest.update!(pending_operation: "creating")
      GuestOperationJob.perform_later(name, "create", memory: memory, vcpus: vcpus,
                                      disk: disk, vif_bridge: vif_bridge)
      redirect_to guest_path(name), notice: "Guest '#{name}' is being created."
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = "Could not create guest: #{e.message}"
      render :new, status: :unprocessable_entity
    end

    def start
      name = params[:name]
      guest = Guest.find_or_create_by!(xen_name: name)
      guest.update!(pending_operation: "starting")
      GuestOperationJob.perform_later(name, "start")
      redirect_to guest_path(name), notice: "Guest '#{name}' is starting."
    end

    def stop
      name = params[:name]
      guest = Guest.find_or_create_by!(xen_name: name)
      guest.update!(pending_operation: "stopping")
      GuestOperationJob.perform_later(name, "stop")
      redirect_to guest_path(name), notice: "Guest '#{name}' is stopping."
    end

    def destroy
      name = params[:name]
      if (guest = Guest.find_by(xen_name: name))
        guest.update!(pending_operation: "destroying")
      end
      GuestOperationJob.perform_later(name, "destroy")
      redirect_to guests_path, notice: "Guest '#{name}' is being deleted."
    end
  end
end
