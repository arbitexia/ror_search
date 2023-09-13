class AddMiddleNameToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :middle_name, :string
  end
end
