class AddDeliveryTrackingToFulfillments < ActiveRecord::Migration[8.1]
  # The lifecycle stamp for confirmed receipt (docs/plans/6.0-fulfillment-and-delivery.md,
  # "Status model — two axes"). The carrier axis itself — status, estimate,
  # scan details, carrier — lives on spree_deliveries
  # (docs/plans/6.0-shipping-labels-and-deliveries.md), never here.
  #
  # Status values themselves are remapped by spree:migrate_fulfillment_statuses
  # rather than here — data transformations never live in migrations.
  def change
    add_column :spree_fulfillments, :delivered_at, :datetime

    # `tracking` is the 5.6 column spree:migrate_deliveries reads; it is
    # dropped in 6.1 once every row has its delivery.
    add_index :spree_fulfillments, :tracking
    add_index :spree_fulfillments, :status
  end
end
