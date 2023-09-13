class CreateClients < ActiveRecord::Migration[5.1]
  def change
    create_table :clients do |t|
      t.timestamps
    end

    add_column :clients, :legal_business_name, :string
    add_column :clients, :physical_address, :string
    add_column :clients, :mailing_address, :string
    add_column :clients, :phone, :string
    add_column :clients, :fax, :string
    add_column :clients, :primary_contact_name, :string
    add_column :clients, :primary_contact_title, :string
    add_column :clients, :primary_contact_email, :string
    add_column :clients, :billing_contact_name, :string
    add_column :clients, :billing_contact_title, :string
    add_column :clients, :billing_contact_email, :string
    add_column :clients, :business_type, :string
    add_column :clients, :state_of_incorporation, :string
    add_column :clients, :tax_id_number, :string
  end
end
