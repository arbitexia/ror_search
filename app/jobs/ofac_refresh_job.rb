class OFACRefreshJob < ApplicationJob
  queue_as :default

  def perform
    # load new OFAC csv
    dir = Rails.root.join('data')
    FileUtils.makedirs(dir)

    begin
      OFACSearcher.regenerate_database
    rescue StandardError => e
      AdminMailer.refresh_job_failed_email('OFAC', e).deliver_now
      raise e
    end

    File.write(Rails.root.join('log', 'sam_update.log'), Date.today.to_s)
  end
end
