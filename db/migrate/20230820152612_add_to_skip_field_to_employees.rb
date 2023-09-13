class AddToSkipFieldToEmployees < ActiveRecord::Migration[6.0]
  def change
    add_column :employees, :skip, :boolean
  end
end
