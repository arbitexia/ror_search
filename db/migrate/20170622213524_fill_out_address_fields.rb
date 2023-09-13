class FillOutAddressFields < ActiveRecord::Migration[5.1]
  def change
    %w[mailing physical billing].each do |address_type|
      %w[city state zip].each do |address_component|
        add_column :clients, "#{address_type}_#{address_component}", :string
      end
    end

    add_column :clients, :billing_address, :string
    add_column :clients, :billing_same_as_mailing, :boolean, default: false
  end
end
