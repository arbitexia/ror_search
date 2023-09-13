class AddRunInitialReportToBatchUploads < ActiveRecord::Migration[6.0]
  def change
    add_column :batch_uploads, :run_initial_report, :boolean
  end
end
