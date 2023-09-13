class AddPrimaryContactToClients < ActiveRecord::Migration[5.1]
  def change
    add_reference :clients, :primary_contact, references: :users
  end
end
