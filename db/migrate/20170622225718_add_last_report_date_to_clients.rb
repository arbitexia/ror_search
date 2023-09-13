class AddLastReportDateToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :next_report_at, :datetime
    add_column :reports, :source, :string
  end
end
