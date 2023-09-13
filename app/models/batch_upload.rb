# == Schema Information
#
# Table name: batch_uploads
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  filename              :string
#  record_type           :string
#  progress              :float
#  error                 :string
#  client_id             :bigint
#  run_initial_report    :boolean
#  imported_record_count :integer
#
class BatchUpload < ApplicationRecord
  belongs_to :client

  has_many :employees, dependent: :nullify
  has_many :vendors, dependent: :nullify

  scope :desc, -> { order(created_at: :desc) }

  def enqueue_job
    BatchUploadJob.perform_later(self)
  end
end
