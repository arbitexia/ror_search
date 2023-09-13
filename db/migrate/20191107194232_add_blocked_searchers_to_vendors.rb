class AddBlockedSearchersToVendors < ActiveRecord::Migration[5.1]
  def change
    add_column :vendors, :blocked_searchers, :text, array: true, default: []
  end
end
