class AddParentReportToReport < ActiveRecord::Migration[6.0]
  def change
    add_reference :reports, :parent_report, references: :reports
  end
end
