class CreateBatchUploads < ActiveRecord::Migration[6.0]
  def change
    create_table :batch_uploads do |t|
      t.timestamps
    end

    add_column :batch_uploads, :filename, :string
    add_column :batch_uploads, :record_type, :string
    add_column :batch_uploads, :progress, :float
    add_column :batch_uploads, :error, :string
    add_reference :batch_uploads, :client
  end
end
