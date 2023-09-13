class AddMonthlyReportDayToClients < ActiveRecord::Migration[6.0]
  def change
    add_column :clients, :monthly_report_day, :integer, default: 1
  end
end
