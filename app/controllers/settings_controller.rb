class SettingsController < ApplicationController
  layout 'portal'

  def index
    @clients = if current_user.is_admin?
      Client.all
    else
      current_user.clients
    end
  end
end
