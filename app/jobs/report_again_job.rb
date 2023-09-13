class ReportAgainJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    report = Report.find_by(job_id: job_id)

    if report && report.status == 'pending'
      ReportGeneratorJob.perform_later(report)
    end
  end
end
