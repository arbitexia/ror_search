class AddiSolvedInfoToFacilities < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :isolved_legal_company_id, :integer
    add_column :clients, :isolved_legal_company_name, :text
    add_column :clients, :isolved_location_id, :integer
    add_column :clients, :isolved_location_name, :text
  end
end
