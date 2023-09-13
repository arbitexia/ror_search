class CreateReports < ActiveRecord::Migration[5.1]
  def change
    create_table :reports do |t|
      t.string :job_id
      t.references :client, foreign_key: true
      t.string :filename

      t.timestamps
    end
  end
end
