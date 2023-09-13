# == Schema Information
#
# Table name: reports
#
#  id               :bigint           not null, primary key
#  report_id        :bigint
#
class FailedReport < ApplicationRecord
  belongs_to :report
  belongs_to :client

  scope :desc, -> { order(created_at: :desc) }
end
