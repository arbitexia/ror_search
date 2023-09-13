class AdminConstraint
  def matches?(request)
    current_user = request.env['warden'].authenticate(scope: :user)
    current_user.present? && current_user.is_admin?
  end
end
