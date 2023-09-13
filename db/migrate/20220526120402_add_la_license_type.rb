class AddLaLicenseType < ActiveRecord::Migration[6.0]
  def up
    add_column :employees, :la_license_type, :integer, default: 0
    add_column :vendors, :la_license_type, :integer, default: 0
  end

  def down
    remove_column :employees, :la_license_type
    remove_column :vendors, :la_license_type
  end
end
