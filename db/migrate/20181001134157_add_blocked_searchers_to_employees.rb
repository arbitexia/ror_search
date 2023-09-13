class AddBlockedSearchersToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :blocked_searchers, :text, array: true, default: []
  end
end
