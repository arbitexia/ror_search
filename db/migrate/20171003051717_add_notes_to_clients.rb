class AddNotesToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :notes, :text
  end
end
