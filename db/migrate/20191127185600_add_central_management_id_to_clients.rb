class AddCentralManagementIdToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :central_management_id, :string
  end
end
