class AddDeliveryTrackingToFulfillments < ActiveRecord::Migration[8.1]
  # The carrier axis (docs/plans/6.0-fulfillment-and-delivery.md, "Status model
  # — two axes"): what the carrier reports, kept apart from what the merchant
  # did. Overwritten on every carrier update, so no history table and no
  # transition graph.
  #
  # Status values themselves are remapped by spree:migrate_fulfillment_statuses
  # rather than here — data transformations never live in migrations.
  def change
    change_table :spree_fulfillments, bulk: true do |t|
      t.string :tracking_status
      t.datetime :estimated_delivery_at
      t.datetime :delivered_at

      if t.respond_to?(:jsonb)
        t.jsonb :tracking_details
      else
        t.json :tracking_details
      end
    end

    # Carrier webhooks arrive keyed by tracking code, so the lookup that
    # resolves one to a fulfillment has to be indexed.
    add_index :spree_fulfillments, :tracking
    add_index :spree_fulfillments, :status
  end
end
