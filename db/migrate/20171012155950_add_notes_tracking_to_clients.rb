class AddNotesTrackingToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :notes_updated_by, :string
    add_column :clients, :notes_updated_at, :datetime
  end
end
