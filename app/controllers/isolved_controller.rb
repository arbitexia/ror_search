class IsolvedController < ApplicationController
  before_action :restrict_to_admin

  def search_clients
    json = IsolvedSearcher.new(params[:endpoint]).search_clients(params[:page].to_i)
    results = json['results']
    results = results.select { |client| filter_name(client['clientName'], params[:query]) }
    render json: { pagination: { more: json['nextPageUrl'].present? }, results: results }
  end

  def search_legal_companies
    client = Client.find(params[:sanction_search_client_id])
    legals = IsolvedSearcher.new(client.isolved_endpoint).search_legal_companies(client.isolved_client_id)
    legals = legals.select { |legal| filter_name(legal['legalName'], params[:query]) }
    render json: { results: legals }
  end

  def search_locations
    client = Client.find(params[:sanction_search_client_id])
    locations = IsolvedSearcher.new(client.isolved_endpoint).search_locations(client.isolved_client_id, params[:legal_id].to_i)
    locations = locations.select { |location| filter_name(location['workLocationDescription'], params[:query]) }
    render json: { results: locations }
  end

  private

  def filter_name(name, query)
    name.downcase.include?(query.to_s.downcase)
  end
end
