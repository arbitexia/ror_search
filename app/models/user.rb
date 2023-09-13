# == Schema Information
#
# Table name: users
#
#  id                          :bigint           not null, primary key
#  email                       :string           default(""), not null
#  encrypted_password          :string           default(""), not null
#  reset_password_token        :string
#  reset_password_sent_at      :datetime
#  remember_created_at         :datetime
#  sign_in_count               :integer          default(0), not null
#  current_sign_in_at          :datetime
#  last_sign_in_at             :datetime
#  current_sign_in_ip          :string
#  last_sign_in_ip             :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  name                        :string
#  title                       :string
#  phone                       :string
#  client_id                   :bigint
#  is_suspended                :boolean
#  receive_notification_emails :boolean          default(TRUE)
#
class User < ApplicationRecord
  #########################################################

  has_and_belongs_to_many :clients
  has_many :primary_contact_clients, class_name: 'Client', inverse_of: :primary_contact,
                                     foreign_key: 'primary_contact_id'

  scope :alphabetical, -> { order(name: :asc) }
  scope :desc, -> { order(created_at: :desc) }

  has_many :notes_updated_for_employee, class_name: 'Employee', inverse_of: :notes_updated_by,
                                        foreign_key: 'notes_updated_by_id', dependent: :nullify
  has_many :notes_updated_for_vendor, class_name: 'Employee', inverse_of: :notes_updated_by,
                                      foreign_key: 'notes_updated_by_id', dependent: :nullify
  has_many :vendors, inverse_of: :notes_updated_by,
           foreign_key: 'notes_updated_by_id', dependent: :nullify

  rolify

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable,
         :masqueradable

  def has_access_to_client?(client)
    has_direct_access = clients.include?(client)
    if client.parent.present?
      has_direct_access || has_access_to_client?(client.parent)
    else
      has_direct_access
    end
  end

  def all_clients_i_can_access
    clients.flat_map do |company|
      [company, *company.facilities, *company.facilities.map(&:facilities)].flatten
    end
  end

  def has_primary_contact_access_to_client?(client)
    has_direct_access = clients.include?(client) && client.primary_contact == self
    if client.parent.present?
      has_direct_access || has_primary_contact_access_to_client?(client.parent)
    else
      has_direct_access
    end
  end

  def self.attributes_from_params(params, merge = {})
    attrs = params.require(:user).permit(
      :name,
      :email,
      :phone,
      :password,
      :receive_notification_emails,
      client_ids: []
    )

    attrs.merge!(merge)

    attrs.delete(:password) unless attrs[:password].present? # don't have a phantom key

    attrs
  end
end
