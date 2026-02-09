# This migration comes from spree (originally 20241218183905)
class AddGatewayCustomerProfileIdToSpreePaymentSources < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_payment_sources, :gateway_customer_profile_id, :string
  end
end
