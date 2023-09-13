class AddTwoFieldsToFailedReports < ActiveRecord::Migration[6.0]
  def change
    add_column :failed_reports, :error, :string
    add_column :failed_reports, :employee_id, :integer
  end
end
