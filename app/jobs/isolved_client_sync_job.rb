class IsolvedClientSyncJob < ApplicationJob
  queue_as :default

  def perform(facility)
    # always performed on a facility as far as I can tell
    raise "No iSolved endpoint on client #{facility.parent}" unless facility.parent.isolved_endpoint.present?
    IsolvedSearcher.new(facility.parent.isolved_endpoint).sync_employees(facility)
  end
end
