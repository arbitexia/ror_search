class AddDeactivatedToClients < ActiveRecord::Migration[6.0]
  def change
    add_column :clients, :deactivated, :boolean, default: false
  end
end
