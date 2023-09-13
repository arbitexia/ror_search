class AddIsolvedEndpointToClients < ActiveRecord::Migration[6.0]
  def change
    add_column :clients, :isolved_endpoint, :string
  end
end
