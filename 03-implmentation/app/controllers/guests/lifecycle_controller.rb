# frozen_string_literal: true

module Guests
  class LifecycleController < ApplicationController
    before_action -> { require_role(:admin, :operator) }

    def new
    end

    def create
      name   = params[:name].to_s.strip
      memory = params[:memory].to_i
      vcpus  = params[:vcpus].to_i

      if name.blank?
        flash.now[:alert] = "Name is required."
        return render :new, status: :unprocessable_entity
      end

      Xen::Lifecycle.create(name: name, memory: memory, vcpus: vcpus)
      Guest.find_or_create_by!(xen_name: name)
      redirect_to guest_path(name), notice: "Guest '#{name}' created and started."
    rescue Xen::CommandError => e
      flash.now[:alert] = "Could not create guest: #{e.stderr.presence || e.message}"
      render :new, status: :unprocessable_entity
    end

    def start
      name = params[:name]
      Xen::Lifecycle.start(name)
      redirect_to guest_path(name), notice: "Guest '#{name}' started."
    rescue Xen::CommandError => e
      redirect_to guest_path(params[:name]), alert: "Could not start guest: #{e.stderr.presence || e.message}"
    end

    def stop
      name = params[:name]
      Xen::Lifecycle.stop(name)
      redirect_to guest_path(name), notice: "Guest '#{name}' stopped."
    rescue Xen::CommandError => e
      redirect_to guest_path(params[:name]), alert: "Could not stop guest: #{e.stderr.presence || e.message}"
    end

    def destroy
      name = params[:name]
      Xen::Lifecycle.destroy(name)
      Guest.find_by(xen_name: name)&.destroy
      redirect_to guests_path, notice: "Guest '#{name}' deleted."
    rescue Xen::CommandError => e
      redirect_to guest_path(name), alert: "Could not delete guest: #{e.stderr.presence || e.message}"
    end
  end
end
