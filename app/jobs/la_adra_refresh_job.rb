class LaAdraRefreshJob < ApplicationJob
  queue_as :default

  def perform
    LaAdraSearcher.regenerate_database
  rescue StandardError => e
    AdminMailer.refresh_job_failed_email('La Adra Disciplinary Actions', e).deliver_now
    raise e
  end
end
