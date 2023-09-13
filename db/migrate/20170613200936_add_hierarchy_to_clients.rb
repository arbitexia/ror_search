class AddHierarchyToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :max_employees, :integer
    add_reference :clients, :parent, references: :clients
    add_column :clients, :client_type, :string, default: :company
  end
end
