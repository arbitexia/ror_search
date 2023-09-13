require 'csv'

class EmployeesController < ApplicationController
  layout 'portal'

  before_action :restrict_to_owning_client_or_admin

  def index
    @client = Client.find(params[:client_id])
    @employees = @client.employees.alphabetical.paginate(page: params[:page], per_page: 20)
  end

  def new
    @client = Client.find(params[:client_id])
    @employee = Employee.new(client: @client)
  end

  def create
    @client = Client.find(params[:client_id])
    @employee = Employee.new(Employee.attributes_from_params(params, client: @client))

    if @employee.notes.present?
      @employee.notes_updated_at = DateTime.now
      @employee.notes_updated_by_id = current_user.id
    end

    if @client.reached_record_count?
      flash[:alert] =
        'You have exceeded your maximum count of employees and vendors. Please remove some records before you can add a new one, or contact us to purchase a higher tier of service.'
      redirect_to client_employees_path(@client)
      return
    end

    if @employee.save
      if params[:run_report_now]
        report = @client.reports.create(source: "Initial report for #{@employee.full_name}",
                                        employee_mask: [@employee.id])
        job = ReportGeneratorJob.perform_later(report)
        report.update(job_id: job.job_id)
      end

      redirect_to client_employees_path(@client)
    else
      render 'new'
    end
  end

  def new_batch
    @client = Client.find(params[:client_id])
  end

  def create_batch
    @client = Client.find(params[:client_id])

    if params[:batch_file].nil?
      @error = 'Please choose a file to upload.'
      render 'new_batch' and return
    end

    file_data = params[:batch_file]
    if file_data.respond_to?(:read)
      csv_contents = file_data.read.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    elsif file_data.respond_to?(:path)
      csv_contents = File.read(file_data.path)
    else
      logger.error "Bad file_data: #{file_data.class.name}: #{file_data.inspect}"
      @error = 'Please upload a file in the correct format.'
      render 'new_batch' and return
    end

    filename = Rails.root.join('data', "batch_upload_#{Date.today}_#{Time.now.to_i}.csv")
    if File.write(filename, csv_contents) > 0
      batch_upload = @client.batch_uploads.create!(
        run_initial_report: params[:run_report_now],
        record_type: 'employee',
        filename: filename
      )
      batch_upload.enqueue_job

      flash[:notice] = 'Batch import started.'
      redirect_to client_batch_uploads_path(@client)
    else
      @error = 'Invalid file or internal server error.'
      render 'new_batch'
    end
  end

  def skip
    employee = Employee.find_by(id: params[:employee_id])
    failed_report = FailedReport.find(params[:failed_report_id])
    if employee.nil?
      error = "Employee not found"
      
      render json: {
        status: 'failed',
        error: error
      }
    else
      if employee.skip?
        employee.update(skip: false)
      else
        employee.update(skip: true)
      end
      
      render json: {
        status: 'success',
        employee_skip_status: employee.skip?
      }
    end
  end

  def show
    redirect_to action: :edit
  end

  def edit
    @client = Client.find(params[:client_id])
    @employee = Employee.find(params[:id])

    flash[:previous_referrer] = request.referrer if request.referrer && request.referrer.include?('/reports/')
  end

  def update
    @client = Client.find(params[:client_id])
    @employee = Employee.find(params[:id])

    attrs = Employee.attributes_from_params(params, client: @client)

    if attrs[:notes] != @employee.notes
      attrs[:notes_updated_at] = DateTime.now
      attrs[:notes_updated_by_id] = current_user.id
    end

    if @employee.update(attrs)
      if params[:run_report_now]
        report = @client.reports.create(source: "Follow-up report for #{@employee.full_name}",
                                        employee_mask: [@employee.id])
        job = ReportGeneratorJob.perform_later(report)
        report.update(job_id: job.job_id)
      end

      previous_referrer = flash[:previous_referrer]
      if previous_referrer.present?
        redirect_to previous_referrer
      else
        redirect_to client_employees_path(@client, page: params[:page])
      end
    else
      render 'edit'
    end
  end

  def destroy
    @client = Client.find(params[:client_id])
    @employee = Employee.find(params[:id])

    @employee.destroy!

    redirect_to client_employees_path(@client, page: params[:page])
  end

  def destroy_all
    @client = Client.find(params[:client_id])
    @client.employees.destroy_all
    redirect_to client_employees_path(@client)
  end

  protected

  def restrict_to_owning_client_or_admin
    @client = Client.find(params[:client_id])
    render_403 unless user_has_access_to_client?(@client)

    if params[:id].present? && Employee.exists?(params[:id]) && !(Employee.find(params[:id]).client_id.to_s == params[:client_id])
      render_403
    end
  end
end
