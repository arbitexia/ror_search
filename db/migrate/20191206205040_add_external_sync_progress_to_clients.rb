class AddExternalSyncProgressToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :external_sync_progress, :float
    add_column :clients, :last_external_sync_at, :datetime
  end
end
