class MSMedicaidRefreshJob < ApplicationJob
  queue_as :default

  def perform
    # load new MS Medicaid xls + parse to csv + parse to sqlite
    dir = Rails.root.join('data')
    FileUtils.makedirs(dir)

    begin
      MSMedicaidSearcher.download_latest_list
      MSMedicaidSearcher.regenerate_database
    rescue StandardError => e
      AdminMailer.refresh_job_failed_email('Mississippi Medicaid', e).deliver_now
      raise e
    end

    File.write(Rails.root.join('log', 'msmedicaid_update.log'), Date.today.to_s)
  end
end
