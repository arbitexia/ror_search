class CentralManagementClientSyncJob < ApplicationJob
  queue_as :default

  def perform(client)
    CentralManagementLoader.sync_employees(client)
  end
end
