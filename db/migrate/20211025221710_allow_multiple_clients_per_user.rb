class AllowMultipleClientsPerUser < ActiveRecord::Migration[6.0]
  def up
    create_join_table :clients, :users do |t|
      t.index :client_id
      t.index :user_id
    end

    User.all.each do |user|
      if user.client.present?
        user.clients << user.client
        user.client = nil
      end
      user.save!
    end
  end

  def down
    User.all.each do |user|
      if user.clients.present?
        user.client = user.clients.first
        user.clients = []
      end
      user.save!
    end

    drop_join_table :clients, :users
  end
end
