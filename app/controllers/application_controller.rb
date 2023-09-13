class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include Pundit::Authorization

  def render_403
    if user_signed_in? && current_user.is_suspended?
      render '/users/disabled'
    else
      render file: Rails.root.join('public/403.html'), status: 403, layout: false
    end
  end

  def restrict_to_admin
    render_403 unless user_signed_in? && !current_user.is_suspended? && current_user.is_admin?
  end

  def user_has_access_to_client?(client)
    user_signed_in? &&
      !current_user.is_suspended? &&
      (current_user.is_admin? || current_user.has_access_to_client?(client))
  end
end
