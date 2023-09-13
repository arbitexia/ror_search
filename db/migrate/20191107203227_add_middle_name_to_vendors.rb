class AddMiddleNameToVendors < ActiveRecord::Migration[5.1]
  def change
    add_column :vendors, :middle_name, :string
  end
end
