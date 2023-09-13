class AddUkgIdToEmployees < ActiveRecord::Migration[6.0]
  def change
    add_column :employees, :ukg_id, :string
    add_column :clients, :ukg_id, :string
  end
end
