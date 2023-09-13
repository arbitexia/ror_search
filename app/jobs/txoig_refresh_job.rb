class TXOIGRefreshJob < ApplicationJob
  queue_as :default

  def perform
    dir = Rails.root.join('data')
    FileUtils.makedirs(dir)

    begin
      # load new TX OIG tsv and import it
      TXOIGSearcher.download_latest_tsv
      TXOIGSearcher.regenerate_database
    rescue StandardError => e
      AdminMailer.refresh_job_failed_email('Texas OIG', e).deliver_now
      raise e
    end

    File.write(Rails.root.join('log', 'txoig_update.log'), Date.today.to_s)
  end
end
