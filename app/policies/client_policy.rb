class ClientPolicy < ApplicationPolicy
  attr_reader :user, :client

  def initialize(user, client)
    @user = user
    @client = client
  end

  def index?
    true
  end

  def show?
    is_admin? || belongs_to_client?
  end

  def new?
    create?
  end

  def create?
    is_admin?
  end

  def edit?
    update?
  end

  def update?
    is_primary_contact? || is_admin?
  end

  def destroy?
    is_admin?
  end

  def post_note?
    is_admin?
  end
  
  def toggle_suspended?
    is_admin?
  end

  def sync_from_isolved?
    is_primary_contact? || is_admin?
  end

  def sync_from_central_management?
    is_primary_contact? || is_admin?
  end

  private

    def is_primary_contact?
      !user.is_suspended? && user.has_primary_contact_access_to_client?(client)
    end

    def belongs_to_client?
      !user.is_suspended? && user.has_access_to_client?(client)
    end
end