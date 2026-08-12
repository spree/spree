class AddTrackingCarrierToFulfillments < ActiveRecord::Migration[8.1]
  # Which carrier a tracking number belongs to. One delivery method can quote
  # several carriers since the multi-rate work, so the method-level tracking
  # URL format cannot answer this; the carrier is pinned per fulfillment —
  # picked by the merchant, detected from the number's format, or implied by
  # the provider that bought the label.
  def change
    add_column :spree_fulfillments, :tracking_carrier, :string
  end
end
