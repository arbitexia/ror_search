# == Schema Information
#
# Table name: employees
#
#  id                    :bigint           not null, primary key
#  first_name            :string
#  last_name             :string
#  dob                   :date
#  ssn                   :string
#  client_id             :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  middle_name           :string
#  blocked_searchers     :text             default([]), is an Array
#  isolved_id            :string
#  central_management_id :string
#  la_license_number     :string
#  tx_license_number     :string
#  batch_upload_id       :bigint
#  notes                 :text
#  notes_updated_at      :datetime
#  notes_updated_by_id   :bigint
#  ukg_id                :string
#  la_license_type       :integer          default("medical")
#
class Employee < ApplicationRecord
  include PrettyDates

  belongs_to :client
  belongs_to :batch_upload, optional: true
  belongs_to :notes_updated_by, class_name: 'User', optional: true

  validates :first_name, presence: true
  validates :last_name, presence: true

  validates :ssn, numericality: true, length: { is: 9 }, allow_nil: true, allow_blank: true

  scope :alphabetical, -> { order(last_name: :asc) }
  scope :desc, -> { order(created_at: :desc) }

  enumerize :la_license_type, in: { medical: 0, adra: 1 }

  before_validation do
    self.dob += 1900.years if dob.present? && dob.year < 100

    self.first_name = first_name.strip
    self.last_name = last_name.strip

    self.ssn = if ssn.present?
                 ssn.gsub(/\W/, '')
               else
                 ''
               end
  end

  def first_name_clean
    self.class.sanitize_name(first_name)
  end

  def last_name_clean
    self.class.sanitize_name(last_name)
  end

  def middle_name_clean
    self.class.sanitize_name(middle_name) if middle_name.present?
  end

  def middle_initial_clean
    middle_name_clean.chars.first if middle_name.present?
  end

  def full_name
    "#{first_name} #{middle_name}".rstrip + " #{last_name}"
  end

  def from_external_sync?
    central_management_id.present? || isolved_id.present? || ukg_id.present?
  end

  def isolved_record
    IsolvedSearcher.find_employee_by_id(client.parent.isolved_client_id, client.isolved_legal_company_id, isolved_id)
  end

  def deep_export
    as_json(except: %i[id client_id])
  end

  class << self
    def attributes_from_params(params, client: nil)
      attributes = params.require(:employee).permit(
        :first_name,
        :middle_name,
        :last_name,
        :dob,
        :ssn,
        :la_license_type,
        :la_license_number,
        :tx_license_number,
        :notes,
        blocked_searchers: []
      ).to_h.merge(client_id: client.id)

      attributes[:dob] = Date.strptime(attributes[:dob], '%m/%d/%Y') if attributes[:dob].present?
      attributes
    end
  end
end
