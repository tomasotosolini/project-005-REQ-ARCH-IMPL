class Admin::UsersController < ApplicationController
  before_action -> { require_grant(:creator) }
  before_action :set_user, only: %i[edit update destroy]

  def index
    @users = User.order(:email)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(create_params)
    if @user.save
      redirect_to admin_users_path, notice: "User created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(update_params)
      redirect_to admin_users_path, notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: "You cannot delete your own account."
      return
    end
    @user.destroy
    redirect_to admin_users_path, notice: "User deleted."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def create_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role)
  end

  def update_params
    p = params.require(:user).permit(:email, :password, :password_confirmation, :role)
    p.delete(:password) if p[:password].blank?
    p.delete(:password_confirmation) if p[:password_confirmation].blank?
    p
  end
end
