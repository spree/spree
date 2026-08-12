class AddRateProviderToDeliveryMethods < ActiveRecord::Migration[7.2]
  def change
    # Blank means the Internal provider (calculator-backed), so existing rows
    # need no backfill.
    add_column :spree_delivery_methods, :rate_provider, :string
  end
end
