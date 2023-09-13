class UkgClientSyncJob < ApplicationJob
  queue_as :default

  def perform(client)
    UkgLoader.sync_employees(client)
  end
end
