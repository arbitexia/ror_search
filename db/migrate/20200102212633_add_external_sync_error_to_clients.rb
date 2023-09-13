class AddExternalSyncErrorToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :external_sync_error, :text
  end
end
