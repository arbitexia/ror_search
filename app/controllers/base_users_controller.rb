class BaseUsersController < ApplicationController
  before_action :restrict_to_admin
  layout 'portal'

  def index
    @users = User.alphabetical
    if params['search'].present?
      query = I18n.transliterate(params['search'].split.map { |a| "#{a}:*" }.join(' & '))
      ts_vector = "to_tsvector(
                  coalesce(unaccent(users.email), '') || ' ' ||
                  coalesce(unaccent(users.name), '')
      )"
      ts_query = "to_tsquery( unaccent('#{query}') )"
      @users = @users.where("#{ts_vector} @@ #{ts_query}")
    end
    @users = @users.paginate(page: params[:page], per_page: 20)
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])

    attributes = User.attributes_from_params(params)
    attributes[:client_ids] = (attributes[:client_ids] || [])
                              .concat(@user.primary_contact_client_ids)
                              .reject { |id| id == '' }
                              .map { |id| id.to_i }
                              .uniq

    if @user.update(attributes)
      flash[:notice] = 'User updated successfully.'
      redirect_to base_users_path
    else
      render 'edit'
    end
  end
end
