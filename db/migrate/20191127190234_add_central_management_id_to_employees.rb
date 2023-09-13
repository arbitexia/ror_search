class AddCentralManagementIdToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :central_management_id, :string
  end
end
