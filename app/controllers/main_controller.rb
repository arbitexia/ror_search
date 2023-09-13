class MainController < ApplicationController
  def index
    if user_signed_in?
      if current_user.clients&.length == 1
        redirect_to client_path(current_user.clients.first)
      else
        redirect_to clients_path
      end
    end
  end

  def splash
    render 'index'
  end

  def contact
    SignupMailer.signup_email(params[:name], params[:email], params[:phone], params[:company_name],
                              params[:employees]).deliver
    flash[:notice] = 'Request submitted. You should expect to hear back soon.'
    redirect_to root_path
  end
end
