class AddLicenseNumberToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :license_number, :string
  end
end
