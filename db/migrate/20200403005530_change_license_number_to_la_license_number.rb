class ChangeLicenseNumberToLaLicenseNumber < ActiveRecord::Migration[5.1]
  def change
    rename_column :employees, :license_number, :la_license_number
  end
end
