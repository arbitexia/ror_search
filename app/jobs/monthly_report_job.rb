class MonthlyReportJob < ApplicationJob
  queue_as :reports

  def perform
    # mark all clients without a scheduled monthly report to have a report run tomorrow
    Client.companies.where(next_report_at: nil).each do |client|
      client.update(next_report_at: DateTime.now + 1.day,
                    automatic_report_info: "had no scheduled report time, so scheduled in one day from #{Date.today}")
    end

    company = Client.companies.where('deactivated = false AND next_report_at <= ?', DateTime.now)
                    .order(next_report_at: :asc).first
    run_company(company) if company.present?
  end

  def run_company(company)
    if company.employees.empty? && company.vendors.empty? && company.facilities.active.empty?
      company.update(next_report_at: DateTime.now + 1.day,
                     automatic_report_info: "had no employees, facilities, or vendors, so scheduled in one day from #{Date.today}")
      return
    end

    # sync facilities and sub-facilities from their employee sources before monthly reports are run
    begin
      all_facilities = company.facilities.active.flat_map { |f| [f].concat(f.facilities) }.uniq
      all_facilities.each do |facility|
        if facility.isolved_legal_company_id.present? && facility.isolved_location_id.present? && facility.has_isolved_employees?
          puts "syncing isolved for #{facility}"
          IsolvedSearcher.new(facility.parent.isolved_endpoint).sync_employees(facility)
        end

        if facility.central_management_id.present? && facility.has_central_management_employees?
          puts "syncing central management for #{facility}"
          CentralManagementLoader.sync_employees(facility)
        end

        if facility.ukg_id.present? && facility.has_ukg_employees?
          puts "syncing UKG for #{facility}"
          UkgLoader.sync_employees(facility)
        end
      end
    rescue StandardError => e
      error_description = e.to_s
      error_backtrace = e.backtrace.join("\n\t")
      error_msg = "had an error syncing from external source, so re-scheduled in one day from #{Date.today}" +
                  "\n\nError was: #{error_description}.\n\n " +
                  "Backtrace: #{error_backtrace}"
      company.update(next_report_at: DateTime.now + 1.day,
                     automatic_report_info: error_msg)
      return
    end

    begin
      report = company.reports.find_or_create_by(source: Report::MONTHLY_REPORT_SOURCE,
                                                 month: Date.today.month, year: Date.today.year)

      next_report_date = company.generate_next_report_date
      company.update(next_report_at: next_report_date,
                     automatic_report_info: "updated to #{next_report_date} before running report job on #{Date.today}")

      ReportGeneratorJob.perform_now(report)

      if report.error.present?
        error_msg = "had an error running the report, so re-scheduled in one day from #{Date.today}"
        company.update(next_report_at: DateTime.now + 1.day, automatic_report_info: error_msg)
      end
    rescue StandardError => e
      error_description = e.to_s
      error_backtrace = e.backtrace.join("\n\t")
      error_msg = 'threw an unhandled error in main rescue block, so scheduled in one day from' +
                  " #{Date.today}.\n\nError was: #{error_description}. \n\n" +
                  " Backtrace: #{error_backtrace}"
      company.update(next_report_at: DateTime.now + 1.day,
                     automatic_report_info: error_msg)
    end
  end
end
