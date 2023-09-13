class AddMasksToReports < ActiveRecord::Migration[6.0]
  def change
    add_column :reports, :employee_mask, :integer, array: true
    add_column :reports, :vendor_mask, :integer, array: true
  end
end
