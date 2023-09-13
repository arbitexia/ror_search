class AddFailedReportsToClients < ActiveRecord::Migration[6.0]
  def change
    add_reference :failed_reports, :client, foreign_key: true
  end
end
