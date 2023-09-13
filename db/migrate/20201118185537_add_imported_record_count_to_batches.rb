class AddImportedRecordCountToBatches < ActiveRecord::Migration[6.0]
  def change
    add_column :batch_uploads, :imported_record_count, :integer
  end
end
