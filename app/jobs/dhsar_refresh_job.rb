class DHSARRefreshJob < ApplicationJob
  queue_as :default

  def perform
    begin
      DHSARSearcher.regenerate_database
    rescue StandardError => e
      AdminMailer.refresh_job_failed_email('Arkansas DHS', e).deliver_now
      raise e
    end

    File.write(Rails.root.join('log', 'dhsar_update.log'), Date.today.to_s)
  end
end
