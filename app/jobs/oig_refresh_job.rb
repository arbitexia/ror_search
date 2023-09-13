class OIGRefreshJob < ApplicationJob
  queue_as :default

  def perform
    OIGSearcher.regenerate_database
  rescue StandardError => e
    AdminMailer.refresh_job_failed_email('OIG', e).deliver_now
    raise e
  end
end
