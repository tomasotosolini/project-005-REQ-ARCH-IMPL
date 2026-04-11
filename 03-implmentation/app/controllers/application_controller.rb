class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def logged_in?
    current_user.present?
  end
  helper_method :logged_in?

  def require_login
    redirect_to login_path, alert: "Please log in." unless logged_in?
  end

  def require_role(*roles)
    unless current_user&.role.in?(roles.map(&:to_s))
      redirect_to login_path, alert: "You are not authorized to perform that action."
    end
  end
end
