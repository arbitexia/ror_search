class AddAutomaticReportInfoToClients < ActiveRecord::Migration[6.0]
  def change
    add_column :clients, :automatic_report_info, :text
  end
end
