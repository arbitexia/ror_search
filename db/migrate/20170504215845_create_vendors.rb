class CreateVendors < ActiveRecord::Migration[5.1]
  def change
    create_table :vendors do |t|
      t.string :name
      t.references :client, foreign_key: true

      t.timestamps
    end
  end
end
