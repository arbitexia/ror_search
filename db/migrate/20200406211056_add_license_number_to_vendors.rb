class AddLicenseNumberToVendors < ActiveRecord::Migration[5.1]
  def change
    add_column :vendors, :la_license_number, :string
  end
end
