class CreateFailedReports < ActiveRecord::Migration[6.0]
  def change
    create_table :failed_reports do |t|
      t.references :report, foreign_key: true

      t.timestamps
    end
  end
end
