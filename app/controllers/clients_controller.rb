class ClientsController < ApplicationController
  layout 'portal'

  ACTIONS_FOR_ONE_CLIENT = %i[show update edit destroy post_note toggle_suspended
                              sync_from_isolved sync_from_central_management]

  before_action :set_client, only: ACTIONS_FOR_ONE_CLIENT
  before_action except: ACTIONS_FOR_ONE_CLIENT do
    if current_user&.is_suspended?
      render_403
    else
      authorize Client
    end
  end

  before_action only: ACTIONS_FOR_ONE_CLIENT do
    if current_user&.is_suspended?
      render_403
    else
      authorize @client
    end
  end

  def index
    @clients = if current_user.is_admin?
      Client.all
    else
      current_user.clients
    end

    @clients = @clients.joins('LEFT JOIN "clients" "facilities_clients" ON "facilities_clients"."parent_id" = "clients"."id" LEFT JOIN "clients" "facilities_clients_2" ON "facilities_clients_2"."parent_id" = "facilities_clients"."id"')
    if params['search'].present?
      query = I18n.transliterate(params['search'].split.map { |a| "#{a}:*" }.join(' & '))
      ts_vector = "to_tsvector(
      coalesce(unaccent(clients.legal_business_name), '')
      || ' ' || coalesce(unaccent(facilities_clients.legal_business_name), '')
      || ' ' || coalesce(unaccent(facilities_clients_2.legal_business_name), '')
      || ' ' || coalesce(unaccent(clients.mailing_address), '')
      || ' ' || coalesce(unaccent(facilities_clients.mailing_address), '')
      || ' ' || coalesce(unaccent(facilities_clients_2.mailing_address), '')
      || ' ' || coalesce(unaccent(clients.primary_contact_name), '')
      || ' ' || coalesce(unaccent(facilities_clients.primary_contact_name), '')
      || ' ' || coalesce(unaccent(facilities_clients_2.primary_contact_name), '')
      || ' ' || coalesce(unaccent(clients.primary_contact_email), '')
      || ' ' || coalesce(unaccent(facilities_clients.primary_contact_email), '')
      || ' ' || coalesce(unaccent(facilities_clients_2.primary_contact_email), '')
      )"
      ts_query = "to_tsquery( unaccent('#{query}') )"
      @clients = @clients.where("#{ts_vector} @@ #{ts_query}")
    end
    @clients = @clients.distinct.order(legal_business_name: :asc).paginate(page: params[:page], per_page: 20)
  end

  def new
    @client = Client.new
    if current_user.is_admin? && params[:parent_id].present?
      @client.parent = Client.find(params[:parent_id])
      @client.client_type = 'facility'
    end
  end

  def create
    @client = Client.new(Client.attributes_from_params(params, current_user))

    if @client.save
      @user = @client.new_contact_user(params[:primary_contact_password])
      if @user.save
        @client.update(primary_contact: @user)
        redirect_to client_path(@client)
      else
        @client.destroy
        @errors = @user.errors
        render 'new'
      end
    else
      @errors = @client.errors
      render 'new'
    end
  end

  def sync_from_isolved
    if @client.employees.empty? || @client.has_isolved_employees?
      IsolvedClientSyncJob.perform_later(@client)
      flash[:notice] = 'Started iSolved sync. Check back in 15min.'
      redirect_to action: :show, client: @client
    elsif current_user.is_admin?
      # create a duplicate of this facility under a fixture client to keep a backup of employee records
      fixture_client_id = if Rails.env.production?
                            120
                          else
                            1
                          end

      fixture_company = Client.find(fixture_client_id)

      attributes = @client.attributes.symbolize_keys.slice(:business_type, :state_of_incorporation,
                                                           :legal_business_name, :physical_address, :tax_id_number, :client_type)
      attributes[:legal_business_name] = "Pre-iSolved Backup of #{attributes[:legal_business_name]}"
      fixture_facility = fixture_company.facilities.create(attributes)
      @client.employees.each do |employee|
        employee.update(client: fixture_facility)
      end

      flash[:notice] =
        "Created #{fixture_facility.legal_business_name} under #{fixture_company.legal_business_name}. Started iSolved sync. Check back in 15min."

      IsolvedClientSyncJob.perform_later(@client)
      redirect_to action: :show, client: @client
    end
  end

  def sync_from_central_management
    if @client.employees.empty? || @client.has_central_management_employees?
      CentralManagementClientSyncJob.perform_later(@client)
      flash[:notice] = 'Started Central Management sync. Check back in 15min.'
      redirect_to action: :show, client: @client
    elsif current_user.is_admin?
      # create a duplicate of this facility under a fixture client to keep a backup of employee records
      fixture_client_id = if Rails.env.production?
                            120
                          else
                            1
                          end

      fixture_company = Client.find(fixture_client_id)

      attributes = @client.attributes.symbolize_keys.slice(:business_type, :state_of_incorporation,
                                                           :legal_business_name, :physical_address, :tax_id_number, :client_type)
      attributes[:legal_business_name] = "Pre-Central Management Backup of #{attributes[:legal_business_name]}"
      fixture_facility = fixture_company.facilities.create(attributes)
      @client.employees.each do |employee|
        employee.update(client: fixture_facility)
      end

      flash[:notice] =
        "Created #{fixture_facility.legal_business_name} under #{fixture_company.legal_business_name}. Started Central Management sync. Check back in 15min."

      CentralManagementClientSyncJob.perform_later(@client)
      redirect_to action: :show, client: @client
    end
  end

  def sync_from_ukg
    @client = Client.find(params[:id])

    if @client.employees.empty? || @client.has_ukg_employees?
      UkgClientSyncJob.perform_later(@client)
      flash[:notice] = 'Started UKG sync. Check back in 15min.'
      redirect_to action: :show, client: @client
    elsif current_user.is_admin?
      # create a duplicate of this facility under a fixture client to keep a backup of employee records
      fixture_client_id = if Rails.env.production?
                            120
                          else
                            1
                          end

      fixture_company = Client.find(fixture_client_id)

      attributes = @client.attributes.symbolize_keys.slice(:business_type, :state_of_incorporation,
                                                           :legal_business_name, :physical_address, :tax_id_number, :client_type)
      attributes[:legal_business_name] = "Pre-UKG Backup of #{attributes[:legal_business_name]}"
      fixture_facility = fixture_company.facilities.create(attributes)
      @client.employees.each do |employee|
        employee.update(client: fixture_facility)
      end

      flash[:notice] =
        "Created #{fixture_facility.legal_business_name} under #{fixture_company.legal_business_name}. Started UKG sync. Check back in 15min."

      UkgClientSyncJob.perform_later(@client)
      redirect_to action: :show, client: @client
    end
  end

  def toggle_suspended
    already_suspended = @client.users.any? { |user| user.is_suspended? }
    @client.recursive_users.each { |user| user.update!(is_suspended: !already_suspended) }
    redirect_to edit_client_path(@client)
  end

  def show
    @users = @client.users.desc.limit(10)
    @employees = @client.employees.desc.limit(10)
    @vendors = @client.vendors.desc.limit(10)
    @reports = @client.reports.desc.limit(10)
    @batch_uploads = @client.batch_uploads.desc.limit(3)
  end

  def edit; end

  def update
    old_attrs = @client.attributes.symbolize_keys
    attrs = Client.attributes_from_params(params, current_user, @client)

    if @client.update(attrs)
      # if attrs[:monthly_report_day].present? && old_attrs[:monthly_report_day].to_i != @client.monthly_report_day
      #   puts "monthly report day changed!!! #{old_attrs[:monthly_report_day].class} #{@client.monthly_report_day}"
      #   updated = @client.update(next_report_at: @client.generate_next_report_date)
      #   if updated
      #     flash[:notice] = "Set next report date to #{@client.next_report_at.strftime("%a, %b %d, %Y")}!"
      #   end
      # end

      @user = @client.update_contact_user(params[:primary_contact_password])

      bypass_sign_in(@user) if @user == current_user

      if @user.errors.present?
        @errors = @user.errors
        render 'edit'
      else
        redirect_back fallback_location: clients_path
      end
    else
      @errors = @client.errors
      render 'edit'
    end
  end

  def post_note
    @client.notes.create!(text: params[:text], user: current_user)

    redirect_to client_path(@client)
  end

  def destroy
    @client.destroy
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end
end
