class AddTxLicenseNumberToEmployees < ActiveRecord::Migration[6.0]
  def change
    add_column :employees, :tx_license_number, :string
  end
end
