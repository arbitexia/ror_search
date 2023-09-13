class AdminMailer < ApplicationMailer
  def refresh_job_failed_email(searcher, e = nil)
    @searcher = searcher
    @e = e
    mail(
      to: ENV['ADMIN_EMAILS'],
      subject: "Sanction Search: Failed to refresh database for '#{searcher}'"
    )
  end
end
