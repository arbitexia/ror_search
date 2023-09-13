class AddBillingContactPhoneToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :billing_contact_phone, :string
  end
end
