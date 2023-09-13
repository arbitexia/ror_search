class UsersController < ApplicationController
  before_action :restrict_to_owning_client_or_admin
  layout 'portal'

  def index
    @client = Client.find(params[:client_id])
    @users = @client.users.alphabetical.paginate(page: params[:page], per_page: 20)
  end

  def new
    @client = Client.find(params[:client_id])
    @user = User.new(receive_notification_emails: true)
    @user.clients << @client
  end

  def show
    redirect_to action: :edit
  end

  def create
    @client = Client.find(params[:client_id])
    @user = User.new(User.attributes_from_params(params))
    @user.clients << @client unless @user.clients.include?(@client)

    if @user.save
      redirect_to client_users_path(@client)
    else
      render 'new'
    end
  end

  def edit
    @client = Client.find(params[:client_id])
    @user = User.find(params[:id])
  end

  def update
    @client = Client.find(params[:client_id])
    @user = User.find(params[:id])

    attributes = User.attributes_from_params(params)
    attributes[:client_ids] = (attributes[:client_ids] || [])
                              .concat(@user.primary_contact_client_ids)
                              .concat([@client.id])
                              .reject { |id| id == '' }
                              .map { |id| id.to_i }
                              .uniq

    if @user.update(attributes)
      if @user == @client.primary_contact
        @client.update!(primary_contact_email: @user.email, primary_contact_name: @user.name,
                        primary_contact_title: @user.title)
      end

      bypass_sign_in(@user) if @user == current_user

      if current_user == @client.primary_contact || current_user == @client.parent&.primary_contact
        redirect_to client_users_path(@client)
      else
        redirect_to client_path(@client)
      end
    else
      render 'edit'
    end
  end

  def make_primary
    @client = Client.find(params[:client_id])
    @user = User.find(params[:id])

    @client.reassign_contact_user(@user)
    @client.save

    redirect_to client_users_path(@client)
  end

  def destroy
    @client = Client.find(params[:client_id])
    @user = User.find(params[:id])
    @user.destroy!
    redirect_back(fallback_location: client_users_path(@client))
  end

  protected

  def restrict_to_owning_client_or_admin
    @client = Client.find(params[:client_id])
    @user = (User.find(params[:id]) if params[:id].present?)

    unless user_signed_in? && !current_user.is_suspended? && (current_user.is_admin? || current_user.has_primary_contact_access_to_client?(@client) || @user == current_user)
      render_403
    end

    render_403 if @user.present? && !@user.has_access_to_client?(@client)
  end
end
