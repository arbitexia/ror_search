class FailedReportsController < ApplicationController
  before_action :restrict_to_admin
  layout 'portal'

  # GET /failed_reports or /failed_reports.json
  def index
    @failed_reports = FailedReport.all.desc
    @total_failed_count = FailedReport.all.count
    @total_success_count = Report.successful.count
    @today_failed_count = FailedReport.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).count
    @today_success_count = Report.successful.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).count
    @report_list = FailedReport.desc.pluck(:client_id)
    @clients = Client.where(id: @report_list).order(legal_business_name: :asc).pluck(:legal_business_name, :id )
    @date_filter = ["This Month", "Last Week", "This Week", "Today"]
    if params['search'].present?
      query = I18n.transliterate(params['search'].split.map { |a| "#{a}:*" }.join(' & '))
      query.gsub!(':', '')
      ts_vector = "to_tsvector(
                  coalesce(unaccent(clients.legal_business_name), '') || ' ' ||
                  coalesce(unaccent(failed_reports.error), '')
      )"
      ts_query = "to_tsquery( unaccent('#{query}') )"
      
      @failed_reports = @failed_reports.joins(:client).where("#{ts_vector} @@ #{ts_query}")
    end
    if params['date_filter'].present?
      current_date = Date.current
      if params['date_filter'] == '1'
        @failed_reports = @failed_reports.where(created_at: current_date.beginning_of_month..current_date.end_of_month)
        @today_success_count = Report.successful.where(created_at: current_date.beginning_of_month..current_date.end_of_month).count
      end
      if params['date_filter'] == '2'
        @failed_reports = @failed_reports.where(created_at: (current_date - 1.week).beginning_of_week..(current_date - 1.week).end_of_week)
        @today_success_count = Report.successful.where(created_at: (current_date - 1.week).beginning_of_week..(current_date - 1.week).end_of_week).count
      end
      if params['date_filter'] == '3'
        @failed_reports = @failed_reports.where(created_at: current_date.beginning_of_week..current_date.end_of_week)
        @today_success_count = Report.successful.where(created_at: current_date.beginning_of_week..current_date.end_of_week).count
      end
      if params['date_filter'] == '4'
        @failed_reports = @failed_reports.where(created_at: current_date.beginning_of_day..current_date.end_of_day)
        @today_success_count = Report.successful.where(created_at: current_date.beginning_of_day..current_date.end_of_day).count
      end

      @today_failed_count = @failed_reports.count
    end
    if params['start_date'].present? && params['end_date'].present?
      @failed_reports = @failed_reports.where(created_at: params['start_date']..params['end_date'])
    elsif params['start_date'].present?
      @failed_reports = @failed_reports.where('reports.created_at >= ?', params['start_date'])
    elsif params['end_date'].present?
      @failed_reports = @failed_reports.where('reports.created_at <= ?', params['end_date'])
    end

    @failed_reports = @failed_reports.where(client_id: params['client_id']) if params['client_id'].present?
    @failed_reports = @failed_reports.paginate(page: params[:page], per_page: 5)
  end

  # GET /failed_reports/1 or /failed_reports/1.json
  def show
    @report = FailedReport.find(params[:id])
    @report_errors = @report.error
    @failed_reason = @report_errors.split('Response headers').first if @report_errors.include?('Response headers')
    @response_body = @report_errors.split('FailedReasonEnd').first.split('Response body: ').second if @report_errors.include?('FailedReasonEnd')
    @failed_employee_id = @report_errors.split('FailedReasonEnd').first.split('FailedEmployeeID: ').second if @report_errors.include?('FailedReasonEnd')
    @valid_html = Nokogiri::HTML(@response_body)
    # fetch employees referenced in the report, if they have been deleted they'll just be missing from this array
    @employees = Employee.where(id: @report.report.data['employees'].map { |record| record['employee']['id'] }) if @report.report.data.present?
    @employees_mask = params[:employees_mask].split(',').map(&:to_i) if params[:employees_mask].present?
    @vendors = Vendor.where(id: @report.report.data['vendors'].map { |record| record['vendor']['id'] }) if @report.report.data.present?
    @vendors_mask = params[:vendors_mask].split(',').map(&:to_i) if params[:vendors_mask].present?

    @employee_error = parse_http_errors

    if params[:masked].present?
      # empty arrays are lost in the request, so if we are explicitly masking our results by a selection
      # but missing a mask for either employees or vendors, assume that means we want to hide that entire category
      @employees_mask ||= []
      @vendors_mask ||= []
    end

    if @employee_error.present?
      employee_id = @report_errors.split('FailedEmployeeID: ').second.split("\n").first
      @failed_employee = Employee.find_by(id: employee_id)
    end
  end

  # def update
  #   @client = Client.find(params[:client_id])
  #   @report = @client.reports.find(params[:id])
  #   @report.update(job_id: ReportGeneratorJob.perform_later(@report).job_id, error: nil, progress: nil)
  #   redirect_to failed_reports_url
  # end

  # GET /failed_reports/1/edit
  def edit; end

  # DELETE /failed_reports/1 or /failed_reports/1.json
  def destroy
    @failed_report.destroy

    respond_to do |format|
      format.html { redirect_to failed_reports_url, notice: "Failed report was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def parse_http_errors    
    employee_error = nil
    if @report_errors.include?('StatusCode:')
      status_code = @report_errors.split("StatusCode: ").second.split("\n").first
      employee_error = "The provided employee information is incorrect or has been blocked from the site.\n Please double-check the employee information or ignore this job regarding to this employee."  if status_code.present?
    end

    employee_error
  end
end
