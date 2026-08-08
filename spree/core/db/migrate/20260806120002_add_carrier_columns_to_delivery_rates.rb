class AddCarrierColumnsToDeliveryRates < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_delivery_rates, :carrier, :string
    add_column :spree_delivery_rates, :service_level, :string
    add_column :spree_delivery_rates, :estimated_delivery_date, :date

    if connection.adapter_name.downcase.include?('postgresql')
      add_column :spree_delivery_rates, :metadata, :jsonb
    else
      add_column :spree_delivery_rates, :metadata, :json
    end
  end
end
