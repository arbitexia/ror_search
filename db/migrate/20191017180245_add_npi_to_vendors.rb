class AddNpiToVendors < ActiveRecord::Migration[5.1]
  def change
    add_column :vendors, :npi, :string
  end
end
