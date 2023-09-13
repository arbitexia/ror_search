class AddBatchUploadToEmployees < ActiveRecord::Migration[6.0]
  def change
    add_reference :employees, :batch_upload, foreign_key: true
    add_reference :vendors, :batch_upload, foreign_key: true
  end
end
