class AddiSolvedIdToEmployees < ActiveRecord::Migration[5.1]
  def change
    add_column :employees, :isolved_id, :string
  end
end
