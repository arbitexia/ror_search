class DHHRefreshJob < ApplicationJob
  queue_as :default

  def perform
    DHHSearcher.regenerate_database
  rescue StandardError => e
    AdminMailer.refresh_job_failed_email('Louisiana LDH Adverse Actions', e).deliver_now
    raise e
  end
end
