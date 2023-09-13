require 'csv'

class VendorsController < ApplicationController
  layout 'portal'

  before_action :restrict_to_owning_client_or_admin

  def index
    @client = Client.find(params[:client_id])
    @vendors = @client.vendors.alphabetical.paginate(page: params[:page], per_page: 20)
  end

  def new
    @client = Client.find(params[:client_id])
    @vendor = Vendor.new(client: @client)
  end

  def create
    @client = Client.find(params[:client_id])
    @vendor = Vendor.new(Vendor.attributes_from_params(params, client: @client))

    if @vendor.notes.present?
      @vendor.notes_updated_at = DateTime.now
      @vendor.notes_updated_by_id = current_user.id
    end

    if @client.reached_record_count?
      flash[:alert] =
        'You have exceeded your maximum count of employees and vendors. Please remove some records before you can add a new one, or contact us to purchase a higher tier of service.'
      redirect_to client_vendors_path(@client)
      return
    end

    if @vendor.save
      if params[:run_report_now]
        report = @client.reports.create(source: "Initial report for #{@vendor.display_name}", vendor_mask: [@vendor.id])
        job = ReportGeneratorJob.perform_later(report)
        report.update(job_id: job.job_id)
      end

      redirect_to client_vendors_path(@client)
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
        record_type: 'vendor',
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

  def show
    redirect_to action: :edit
  end

  def edit
    @client = Client.find(params[:client_id])
    @vendor = Vendor.find(params[:id])
  end

  def update
    @client = Client.find(params[:client_id])
    @vendor = Vendor.find(params[:id])

    attrs = Vendor.attributes_from_params(params, client: @client)

    if attrs[:notes] != @vendor.notes
      attrs[:notes_updated_at] = DateTime.now
      attrs[:notes_updated_by_id] = current_user.id
    end

    if @vendor.update(attrs)
      if params[:run_report_now]
        report = @client.reports.create(source: "Follow-up report for #{@vendor.display_name}",
                                        vendor_mask: [@vendor.id])
        job = ReportGeneratorJob.perform_later(report)
        report.update(job_id: job.job_id)
      end

      redirect_to client_vendors_path(@client, page: params[:page])
    else
      render 'edit'
    end
  end

  def destroy
    @client = Client.find(params[:client_id])
    @vendor = Vendor.find(params[:id])

    @vendor.destroy!

    redirect_to client_vendors_path(@client, page: params[:page])
  end

  def destroy_all
    @client = Client.find(params[:client_id])
    @client.vendors.destroy_all
    redirect_to client_vendors_path(@client)
  end

  protected

  def restrict_to_owning_client_or_admin
    @client = Client.find(params[:client_id])
    render_403 unless user_has_access_to_client?(@client)

    if params[:id].present? && Vendor.exists?(params[:id]) && !(Vendor.find(params[:id]).client_id.to_s == params[:client_id])
      render_403
    end
  end
end
