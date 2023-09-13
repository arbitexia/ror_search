class AdminsController < ApplicationController
  before_action :restrict_to_admin
  layout 'portal'

  def index
    @users = User.all.with_role(:admin).distinct.paginate(page: params[:page], per_page: 20)
  end

  def new
    @user = User.new
  end

  def show
    @user = User.find(params[:id])
    redirect_to edit_admin_path(@user)
  end

  def create
    @user = User.new(User.attributes_from_params(params))
    if @user.save
      @user.add_role(:admin)
      redirect_to admins_path
    else
      render 'new'
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if @user.update(User.attributes_from_params(params))
      @user.add_role(:admin) unless @user.has_role?(:admin)
      redirect_to admins_path
    else
      render 'edit'
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy!
    redirect_back(fallback_location: admins_path)
  end
end
