class PAMedicheckRefreshJob < ApplicationJob
  queue_as :default

  def perform
    PAMedicheckSearcher.regenerate_database
  rescue StandardError => e
    AdminMailer.refresh_job_failed_email('PA Medicheck', e).deliver_now
    raise e
  end
end
