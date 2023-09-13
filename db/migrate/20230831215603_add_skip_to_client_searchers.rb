class AddSkipToClientSearchers < ActiveRecord::Migration[6.0]
  def change
    add_column :client_searchers, :skip, :boolean
  end
end
