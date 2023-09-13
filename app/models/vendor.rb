# == Schema Information
#
# Table name: vendors
#
#  id                  :bigint           not null, primary key
#  name                :string
#  client_id           :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ein                 :string
#  npi                 :string
#  first_name          :string
#  last_name           :string
#  blocked_searchers   :text             default([]), is an Array
#  middle_name         :string
#  la_license_number   :string
#  tx_license_number   :string
#  batch_upload_id     :bigint
#  notes               :text
#  notes_updated_at    :datetime
#  notes_updated_by_id :bigint
#  la_license_type     :integer          default("medical")
#
class Vendor < ApplicationRecord
  include PrettyDates

  belongs_to :client
  belongs_to :batch_upload, optional: true
  belongs_to :notes_updated_by, class_name: 'User', optional: true

  validate do
    unless name.present? || (first_name.present? && last_name.present?)
      errors.add('name',
                 'must specify either entity name or first/last name')
    end
  end
  validates :ein, numericality: true, length: { is: 9 }, allow_nil: true, allow_blank: true

  scope :alphabetical, -> { order('concat(name, last_name) asc') }
  scope :desc, -> { order(created_at: :desc) }
  enumerize :la_license_type, in: { medical: 0, adra: 1 }

  def name_clean
    self.class.sanitize_name(name) if name.present?
  end

  def first_name_clean
    self.class.sanitize_name(first_name) if first_name.present?
  end

  def last_name_clean
    self.class.sanitize_name(last_name) if last_name.present?
  end

  def middle_name_clean
    self.class.sanitize_name(middle_name) if middle_name.present?
  end

  def middle_initial_clean
    middle_name_clean.chars.first if middle_name.present?
  end

  def last_name_or_entity_name_clean
    if last_name.present?
      last_name_clean
    else
      name_clean
    end
  end

  def display_name
    if name.present?
      name
    else
      "#{last_name&.rstrip}, #{first_name&.rstrip} #{middle_name&.rstrip}".rstrip
    end
  end

  def deep_export
    as_json(except: %i[id client_id])
  end

  class << self
    def attributes_from_params(params, client: nil)
      params.require(:vendor).permit(:name,
                                     :first_name,
                                     :last_name,
                                     :middle_name,
                                     :ein,
                                     :npi,
                                     :la_license_type,
                                     :la_license_number,
                                     :tx_license_number,
                                     :notes,
                                     blocked_searchers: []).to_h.merge({ client_id: client.id })
    end
  end
end
