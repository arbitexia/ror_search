class BatchUploadsController < ApplicationController
  layout 'portal'

  before_action :restrict_to_owning_client_or_admin

  def index
    @client = Client.find(params[:client_id])
    @batch_uploads = @client.batch_uploads.desc.paginate(page: params[:page], per_page: 20)
  end

  protected

  def restrict_to_owning_client_or_admin
    @client = Client.find(params[:client_id])
    render_403 unless user_has_access_to_client?(@client)

    if params[:id].present? && Report.exists?(params[:id]) && !(Report.find(params[:id]).client_id.to_s == params[:client_id])
      render_403
    end
  end
end
