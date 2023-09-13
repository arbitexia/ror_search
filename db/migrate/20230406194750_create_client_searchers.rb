class CreateClientSearchers < ActiveRecord::Migration[6.0]
  def change
    create_table :client_searchers do |t|
      t.references :client, null: false, foreign_key: true, index: true
      t.integer :searcher
      t.boolean :enabled, default: true
      t.timestamps
    end

    Client.find_each do |client|
      ClientSearcher.searcher.values.each do |searcher|
        ClientSearcher.create!(client: client, searcher: searcher, enabled: true)
      end
    end
    ClientSearcher.where(searcher: 'TmuArkansasSearcher').update_all(enabled: false)
  end
end
