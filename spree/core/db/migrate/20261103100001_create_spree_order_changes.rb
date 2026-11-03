class CreateSpreeOrderChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_order_changes do |t|
      t.references :order, null: false
      # Staff only — a customer-initiated change leaves it nil.
      t.references :requested_by, polymorphic: true, index: { name: 'index_spree_order_changes_on_requested_by' }
      # The business operation that opened the set; none for an admin edit.
      t.references :return
      t.references :exchange
      t.references :claim
      t.string :status, null: false
      t.datetime :requested_at
      t.datetime :confirmed_at
      t.datetime :canceled_at
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    add_index :spree_order_changes, :status

    # One open set per order. MySQL and MariaDB have no partial index, so
    # there Spree::OrderChanges::Begin holds the order's row lock instead.
    if connection.supports_partial_index?
      add_index :spree_order_changes, :order_id, unique: true,
                                                 where: "status IN ('pending', 'requested')",
                                                 name: 'index_spree_order_changes_one_open_per_order'
    end

    create_table :spree_order_change_actions do |t|
      t.references :order_change, null: false
      t.string :kind, null: false
      t.references :line_item
      t.references :variant
      t.references :fulfillment
      t.references :delivery_method
      t.integer :quantity
      t.integer :position, null: false, default: 0
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end
  end
end
