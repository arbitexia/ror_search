class AddDataToReports < ActiveRecord::Migration[5.1]
  def change
    add_column :reports, :progress, :float
    add_column :reports, :error, :string
    add_column :reports, :status, :string
    add_column :reports, :data, :json
  end
end
