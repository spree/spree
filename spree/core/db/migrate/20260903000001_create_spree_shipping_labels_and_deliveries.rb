class CreateSpreeShippingLabelsAndDeliveries < ActiveRecord::Migration[8.1]
  # Two records with a polymorphic owner (Fulfillment | Return): a shipping
  # label is the carrier document the merchant bought or uploaded, a delivery
  # is one consignment's carrier journey (docs/plans/6.0-shipping-labels-and-deliveries.md).
  # `status` on both is written by the creating workflow, never a database
  # default.
  def change
    create_table :spree_shipping_labels do |t|
      t.references :owner, polymorphic: true, null: false
      t.references :store, null: false
      t.references :integration
      t.string :source, null: false
      t.string :external_id
      t.string :carrier
      t.string :service
      t.string :tracking_number
      t.decimal :cost, precision: 10, scale: 2, null: false, default: 0
      t.string :currency
      t.string :format
      t.string :status, null: false
      t.datetime :refunded_at

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_shipping_labels, [:owner_type, :owner_id]

    # One live label per parcel, enforced where the race actually happens: two
    # clicks on "buy label" both pass an application-level check, and the
    # loser has to be refused before the carrier is charged. A refunded label
    # is history and does not count, so the index is partial where the
    # database supports it.
    if connection.supports_partial_index?
      add_index :spree_shipping_labels, [:owner_type, :owner_id],
                unique: true,
                where: "status <> 'refunded'",
                name: 'index_spree_shipping_labels_on_active_owner'
    end

    create_table :spree_deliveries do |t|
      t.references :owner, polymorphic: true, null: false
      t.references :store, null: false
      t.references :shipping_label, index: { unique: true }
      t.string :tracking_number, null: false
      t.string :tracking_url
      t.string :carrier
      t.string :service
      t.string :status, null: false
      t.datetime :estimated_delivery_at
      t.datetime :delivered_at

      if t.respond_to?(:jsonb)
        t.jsonb :details
      else
        t.json :details
      end

      t.timestamps
    end

    # Carrier webhooks arrive keyed by tracking number and are matched inside
    # the integration's store.
    add_index :spree_deliveries, [:store_id, :tracking_number]
    add_index :spree_deliveries, [:owner_type, :owner_id, :tracking_number],
              unique: true, name: 'index_spree_deliveries_on_owner_and_tracking_number'
  end
end
