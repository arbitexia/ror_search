# == Schema Information
#
# Table name: clients
#
#  id                         :bigint           not null, primary key
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  legal_business_name        :string
#  physical_address           :string
#  mailing_address            :string
#  phone                      :string
#  fax                        :string
#  primary_contact_name       :string
#  primary_contact_title      :string
#  primary_contact_email      :string
#  billing_contact_name       :string
#  billing_contact_title      :string
#  billing_contact_email      :string
#  business_type              :string
#  state_of_incorporation     :string
#  tax_id_number              :string
#  billing_contact_phone      :string
#  max_employees              :integer
#  parent_id                  :bigint
#  client_type                :string           default("company")
#  mailing_city               :string
#  mailing_state              :string
#  mailing_zip                :string
#  physical_city              :string
#  physical_state             :string
#  physical_zip               :string
#  billing_city               :string
#  billing_state              :string
#  billing_zip                :string
#  billing_address            :string
#  billing_same_as_mailing    :boolean          default(FALSE)
#  next_report_at             :datetime
#  monthly_report_day         :integer          default(1)
#  primary_contact_id         :bigint
#  notes                      :text
#  notes_updated_by           :string
#  notes_updated_at           :datetime
#  isolved_client_id          :integer
#  isolved_client_name        :text
#  isolved_legal_company_id   :integer
#  isolved_legal_company_name :text
#  isolved_location_id        :integer
#  isolved_location_name      :text
#  central_management_id      :string
#  external_sync_progress     :float
#  last_external_sync_at      :datetime
#  external_sync_error        :text
#  automatic_report_info      :text
#  deactivated                :boolean          default(FALSE)
#  ukg_id                     :string
#
class Client < ApplicationRecord
  BUSINESS_TYPES = ['LLC', 'Corporation', 'S Corporation', 'Sole Proprietorship', 'Partnership', 'Other']

  has_many :employees, dependent: :destroy
  has_many :vendors, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :failed_reports, dependent: :destroy
  has_many :batch_uploads, dependent: :destroy
  has_many :client_searchers, dependent: :destroy

  after_create :create_client_searchers

  belongs_to :parent, class_name: 'Client', optional: true
  has_many :facilities, class_name: 'Client', foreign_key: :parent_id, dependent: :destroy

  has_and_belongs_to_many :users
  belongs_to :primary_contact, class_name: 'User', dependent: :destroy, optional: true

  has_many :notes, dependent: :destroy

  # TODO: validations
  validates :business_type, presence: true, inclusion: { in: BUSINESS_TYPES }
  validates :state_of_incorporation, presence: true, inclusion: { in: ClientsHelper::STATES }
  validates :legal_business_name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :physical_address, presence: true
  validates :tax_id_number, numericality: true, length: { is: 9 }

  validate do
    if is_company?
      self.parent = nil
    elsif is_facility?
      if parent.nil?
        errors.add(:parent, 'should be specified for a facility')
      elsif parent == self
        errors.add(:parent, 'a facility cannot be its own parent company')
      end
    else
      errors.add(:client_type, 'should be either company or facility')
    end
  end

  scope :companies, -> { where(client_type: :company) }
  scope :facilities, -> { where(client_type: :facility) }
  scope :active, -> { where(deactivated: false) }

  before_validation do
    self.tax_id_number = tax_id_number.gsub(/\W/, '')
  end

  def create_client_searchers
    ClientSearcher.searcher.values.each do |searcher|
      ClientSearcher.create!(client: self, searcher: searcher, enabled: true)
    end
  end

  def generate_next_report_date(first_of_month = DateTime.now.at_beginning_of_month.next_month)
    first_of_month.change(day: monthly_report_day)
  end

  def to_s
    legal_business_name
  end

  def is_company?
    client_type.to_s == 'company'
  end

  def is_facility?
    client_type.to_s == 'facility'
  end

  def has_isolved_employees?
    employees.where.not(isolved_id: nil).count > 0
  end

  def has_central_management_employees?
    employees.where.not(central_management_id: nil).count > 0
  end

  def has_ukg_employees?
    employees.where.not(ukg_id: nil).count > 0
  end

  def new_contact_user(password)
    user = User.new(
      name: primary_contact_name,
      email: primary_contact_email,
      title: primary_contact_title,
      phone: phone,
      password: password,
      password_confirmation: password
    )
    user.clients << self
    user
  end

  def update_contact_user(password)
    attributes = {
      name: primary_contact_name,
      email: primary_contact_email,
      title: primary_contact_title,
      phone: phone
    }

    if password.present?
      attributes[:password] = password
      attributes[:password_confirmation] = password
    end

    if primary_contact.nil?
      self.primary_contact = users.first
      save
    end
    primary_contact.update(attributes)
    primary_contact
  end

  def reassign_contact_user(user)
    self.primary_contact = user
    self.primary_contact_name = user.name
    self.primary_contact_email = user.email
    self.primary_contact_title = user.title
    self.phone = user.phone
    user
  end

  def would_exceed_record_count?(new_records)
    if parent.present?
      parent.would_exceed_record_count?(new_records) || flat_reached_record_count?
    else
      max_employees.present? && facility_record_count + (employees.count + vendors.count + new_records) >= max_employees
    end
  end

  def reached_record_count?
    would_exceed_record_count?(0)
  end

  def flat_would_exceed_record_count?(new_records)
    max_employees.present? && (employees.count + vendors.count + new_records) >= max_employees
  end

  def flat_reached_record_count?
    flat_would_exceed_record_count?(0)
  end

  def facility_record_count
    facilities.map(&:employees).map(&:count).sum + facilities.map(&:vendors).map(&:count).sum
  end

  def recursive_users
    users + facilities.map(&:recursive_users).reduce([]) { |accum, b| accum.concat(b) }
  end

  # checks if this facility or any parent facility/company is deactivated
  def recursively_deactivated?
    if parent.present?
      deactivated? || parent.recursively_deactivated?
    else
      deactivated?
    end
  end

  def enabled_vendor_searchers
    ClientSearcher.vendor_searchers & client_searchers.enabled.map { |cs| cs.searcher.constantize }
  end

  class << self
    def organized_for_selection
      clients = Client.companies.order(:legal_business_name)
      ordered_clients = clients.flat_map do |company|
        [company, *company.facilities, *company.facilities.map(&:facilities)].flatten.uniq
      end
      ordered_clients.collect do |client|
        label = if client.is_facility?
                  '--> ' + client.legal_business_name
                else
                  client.legal_business_name
                end

        [label, client.id]
      end
    end

    def attributes_from_params(params, user, existing_record = nil)
      attrs = params.require(:client).permit(
        :legal_business_name,
        :monthly_report_day,
        :next_report_at,
        :isolved_endpoint,
        :isolved_client_id,
        :isolved_client_name,
        :isolved_legal_company_id,
        :isolved_legal_company_name,
        :isolved_location_id,
        :isolved_location_name,
        :central_management_id,
        :ukg_id,
        :physical_address,
        :physical_city,
        :physical_state,
        :physical_zip,
        :mailing_address,
        :mailing_city,
        :mailing_state,
        :mailing_zip,
        :billing_address,
        :billing_city,
        :billing_state,
        :billing_zip,
        :billing_same_as_mailing,
        :phone,
        :fax,
        :primary_contact_name,
        :primary_contact_title,
        :primary_contact_email,
        :billing_contact_name,
        :billing_contact_title,
        :billing_contact_email,
        :billing_contact_phone,
        :business_type,
        :state_of_incorporation,
        :tax_id_number,
        :max_employees,
        :parent_id,
        :client_type,
        :notes,
        :deactivated
      ).to_h

      unless user.is_admin?
        attrs.delete :parent_id
        attrs.delete :client_type
        attrs.delete :max_employees
        attrs.delete :monthly_report_day
        attrs.delete :next_report_at
      end

      if user.is_admin?
        if attrs[:notes].present? && attrs[:notes] != existing_record&.notes
          attrs[:notes_updated_by] = user.name
          attrs[:notes_updated_at] = DateTime.now
        end

        if attrs[:isolved_client_id].to_s == '0'
          attrs[:isolved_client_id] = nil
          attrs[:isolved_client_name] = nil
        end

        if attrs[:isolved_legal_company_id].to_s == '0'
          attrs[:isolved_legal_company_id] = nil
          attrs[:isolved_legal_company_name] = nil
        end

        if attrs[:isolved_location_id].to_s == '0'
          attrs[:isolved_location_id] = nil
          attrs[:isolved_location_name] = nil
        end
      else
        attrs.delete :notes
        attrs.delete :isolved_endpoint
        attrs.delete :isolved_client_id
        attrs.delete :isolved_client_name
        attrs.delete :isolved_legal_company_id
        attrs.delete :isolved_legal_company_name
        attrs.delete :isolved_location_id
        attrs.delete :isolved_location_name
        attrs.delete :central_management_id
        attrs.delete :ukg_id
      end

      attrs
    end
  end

  def export_file
    dir = Rails.root.join('data_exports')
    FileUtils.mkdir(dir) unless File.exist?(dir)

    filename = dir.join("client_#{id}_#{DateTime.now.strftime('%Y%m%d')}.json")

    File.write(filename, deep_export.to_json)

    puts filename
  end

  def self.import_file(path)
    json = JSON.parse(File.read(path))

    pp "importing json with length: #{json.length}"

    deep_import(json, nil)
  end

  def deep_export
    data = {}
    data[:client] = as_json(except: :id)
    data[:facilities] = facilities.map(&:deep_export)
    data[:employees] = employees.map(&:deep_export)
    data[:vendors] = vendors.map(&:deep_export)

    data
  end

  def self.deep_import(data, parent)
    data['client'].delete('notes')
    client = Client.create!(data['client'].merge({ 'parent': parent }))

    data['facilities'].each { |f| client.facilities.deep_import(f, client) }
    data['employees'].each { |e| client.employees.create!(e) }
    data['vendors'].each { |v| client.vendors.create!(v) }
  end
end
