class ReportGeneratorJob < ApplicationJob
  queue_as :reports


  after_perform do |job|
    @report.update(job_id: self.job_id)
    ReportAgainJob.perform_later(self.job_id)
  end

  def perform(company_report)
    @report = company_report
    client = company_report.client

    if client.deactivated?
      company_report.update(progress: nil, error: 'Client was deactivated prior to report being run')
      return
    end

    if client.is_company? && company_report.employee_mask.nil? && company_report.vendor_mask.nil?
      facility_reports = []

      client.facilities.active.map do |facility|
        facility_report = facility.reports.find_or_create_by(source: company_report.source,
                                                             parent_report: company_report)
        facility_reports << facility_report
        # go one level deep into facilities
        facility.facilities.active.each do |subfacility|
          facility_reports << subfacility.reports.find_or_create_by(source: company_report.source,
                                                                    parent_report: facility_report)
        end
      end

      company_report.update(progress: 0)

      facility_reports.each do |report|
        run_report(report)
      end

      if facility_reports.map(&:error).any? { |error| !error.nil? }
        facilities_with_error = facility_reports.select { |r| !r.error.nil? }.map(&:client)
        facility_names = facilities_with_error.map(&:legal_business_name).join(', ')
        company_report.update(progress: nil,
                              error: "The following facilities had errors, please check their reports for details: #{facility_names}")
      else
        run_report(company_report)
      end

      # add all facility report results to the main one
      facility_reports.map(&:data).each do |data|
        company_report.data['employees'].concat(data['employees']) if company_report.data.present?
        company_report.data['vendors'].concat(data['vendors']) if company_report.data.present?
      end

      company_report.save
    else
      # either running a facility report or a temporary one (reports.rake)
      # or initial report for a single/batch of employees
      run_report(company_report)
    end

    company_report.update(status: 'queued') unless company_report.status == 'pending'
  end

  def run_report(report)
    return if report.complete? # Avoid dups

    client = report.client
    puts "Client: #{client.legal_business_name}"

    total = if report.employee_mask.present?
              report.employee_mask.count
            elsif report.vendor_mask.present?
              report.vendor_mask.count
            else
              client.employees.count + client.vendors.count
            end
    current = 0

    data = {
      employees: [],
      vendors: []
    }

    employees_to_process = if report.employee_mask.present?
                             Employee.where(id: report.employee_mask)
                           elsif report.vendor_mask.present?
                             []
                           else
                             client.employees
                           end

    employees_to_process.each do |employee|
      next if employee.skip?

      results_by_searcher = client.client_searchers.enabled.map do |client_searcher|
        next if client_searcher.skip?

        searcher = client_searcher.searcher.constantize
        results = searcher.search_employee(employee)
        results.map do |result|
          result['searcher'] = searcher.to_s
          result
        end
      end
      results_by_searcher.compact!

      data[:employees] << {
        employee: employee.as_json,
        results: results_by_searcher.reduce(:+),
        blocked_searchers: employee.blocked_searchers
      }

      current += 1
      report.update(progress: current.to_f / total) if report.present?
    end

    vendors_to_process = if report.employee_mask.present?
                           []
                         elsif report.vendor_mask.present?
                           report.vendor_mask.map { |id| Vendor.find(id) }
                         else
                           client.vendors
                         end

    vendors_to_process.each do |vendor|
      results_by_searcher = client.enabled_vendor_searchers.map do |searcher|
        results = searcher.search_vendor(vendor)
        results&.map do |result|
          result['searcher'] = searcher.to_s
          result
        end
      end

      data[:vendors] << {
        vendor: vendor,
        results: results_by_searcher.reduce(:+),
        blocked_searchers: vendor.blocked_searchers
      }

      current += 1
      report.update(progress: current.to_f / total) if report.present?
    end

    if report.present?
      report.update(data: data, progress: nil, status: 'completed')

      if report.source == Report::MONTHLY_REPORT_SOURCE && report.client.present?
        users_to_notify = report.client.users.where(receive_notification_emails: true)
        users_to_notify.each do |user|
          SignupMailer.report_email(user.email).deliver_later
        end
      end
    end

  rescue StandardError => e
    # status.update(error: e.to_s)
    error = [e.to_s, $@].join("\n")
    # report.mark_failure(error) if report.present?
    if report.present?
      report.update(progress: nil, error: error, status: 'pending')
      employee_id = report.employee_mask if report.employee_mask.present?
      failed_report = FailedReport.new(report_id: report.id, client_id: report.client.id, error: e.to_s, employee_id: employee_id)
      #report.build_failed_report(error: e.to_s, employee_id: employee_id, client_id: report.client.id)
      if report.save
        failed_report.save
      end
    end
  end
end
