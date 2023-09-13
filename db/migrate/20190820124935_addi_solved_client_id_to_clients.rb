class AddiSolvedClientIdToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :isolved_client_id, :integer
    add_column :clients, :isolved_client_name, :text
  end
end
