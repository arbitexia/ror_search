class AddMonthYearMonthlyReport < ActiveRecord::Migration[6.0]
  def change
    add_column :reports, :month, :integer, default: nil
    add_column :reports, :year, :integer, default: nil
  end
end
