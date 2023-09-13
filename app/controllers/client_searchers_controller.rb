class ClientSearchersController < ApplicationController
  before_action :restrict_to_admin

  def toggle_enabled
    @client_searcher = ClientSearcher.find(params[:id])
    @client_searcher.update(enabled: !@client_searcher.enabled)
    head :ok
  end

  def toggle_enabled_for_all_clients
    @client_searchers = ClientSearcher.where(searcher: params[:id])
    @client_searchers.each do |client_searcher|
      client_searcher.update(skip: !client_searcher.skip)
    end
    head :ok
  end
end
