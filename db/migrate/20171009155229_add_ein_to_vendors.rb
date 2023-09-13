class AddEinToVendors < ActiveRecord::Migration[5.1]
  def change
    add_column :vendors, :ein, :string
  end
end
