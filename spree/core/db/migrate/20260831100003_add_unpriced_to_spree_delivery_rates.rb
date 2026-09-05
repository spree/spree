class AddUnpricedToSpreeDeliveryRates < ActiveRecord::Migration[8.1]
  def change
    # A rate whose price is not known yet — freight quoted by a forwarder
    # after the merchant reviews the order. Distinct from a rate that costs
    # nothing, which is what a bare zero would say.
    add_column :spree_delivery_rates, :unpriced, :boolean, null: false, default: false
  end
end
