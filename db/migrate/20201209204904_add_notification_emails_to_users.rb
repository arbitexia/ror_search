class AddNotificationEmailsToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column :users, :receive_notification_emails, :boolean, default: true
  end

  def down
    remove_column :users, :receive_notification_emails
  end
end
