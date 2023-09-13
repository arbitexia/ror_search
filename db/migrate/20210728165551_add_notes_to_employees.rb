class AddNotesToEmployees < ActiveRecord::Migration[6.0]
  def change
    add_column :employees, :notes, :text
    add_column :employees, :notes_updated_at, :datetime
    add_reference :employees, :notes_updated_by, foreign_key: true, foreign_key: { to_table: :users }

    add_column :vendors, :notes, :text
    add_column :vendors, :notes_updated_at, :datetime
    add_reference :vendors, :notes_updated_by, foreign_key: true, foreign_key: { to_table: :users }
  end
end
