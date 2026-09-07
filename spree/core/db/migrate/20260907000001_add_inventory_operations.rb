class AddInventoryOperations < ActiveRecord::Migration[8.1]
  def change
    # A transfer becomes a multi-day operation with its own status, and gains
    # the store it has never carried (docs/plans/6.0-inventory-operations.md).
    # `source_location_id` stays nullable: emptying it of the external-receive
    # rows is the upgrade task's job, not a migration's.
    add_column :spree_stock_transfers, :store_id, :bigint
    add_column :spree_stock_transfers, :status, :string
    add_column :spree_stock_transfers, :shipped_at, :datetime
    add_column :spree_stock_transfers, :received_at, :datetime
    add_column :spree_stock_transfers, :notes, :text
    add_column :spree_stock_transfers, :created_by_id, :bigint
    # The upgrade task soft-deletes the external receives it converts into
    # purchase orders, so their T-… numbers stay findable without the receive
    # showing up twice.
    add_column :spree_stock_transfers, :deleted_at, :datetime
    add_index :spree_stock_transfers, :store_id
    add_index :spree_stock_transfers, :status
    add_index :spree_stock_transfers, :deleted_at

    # An STI column that never had a subclass to hold: always null, exposed by
    # nothing (docs/plans/6.0-inventory-operations.md, phase 6).
    remove_column :spree_stock_transfers, :type, :string

    create_table :spree_stock_transfer_items do |t|
      t.references :stock_transfer, null: false
      t.references :variant, null: false
      t.integer :quantity_shipped, null: false, default: 0
      t.integer :quantity_received, null: false, default: 0
      t.string :discrepancy_reason
      t.timestamps
    end
    add_index :spree_stock_transfer_items, [:stock_transfer_id, :variant_id],
              unique: true, name: 'idx_stock_transfer_items_unique'

    create_table :spree_suppliers do |t|
      t.string :name, null: false
      t.string :contact_name
      t.string :email
      t.string :phone
      t.text :notes
      t.references :store, null: false
      # Inline address columns, mirroring spree_stock_locations: a supplier is
      # a place goods come from, edited as one flat form.
      t.string :address1
      t.string :address2
      t.string :city
      t.string :state_name
      t.string :state_code
      t.string :country_code
      t.string :postal_code
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :spree_suppliers, [:store_id, :name], unique: true
    add_index :spree_suppliers, :deleted_at

    create_table :spree_purchase_orders do |t|
      t.string :number, null: false
      t.string :status
      t.string :currency, null: false
      t.string :reference
      t.references :supplier, null: false
      t.references :store, null: false
      t.references :destination_location, null: false
      t.date :expected_at
      t.datetime :ordered_at
      t.datetime :received_at
      t.text :notes
      t.bigint :created_by_id
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end
    add_index :spree_purchase_orders, :number, unique: true
    add_index :spree_purchase_orders, :status

    create_table :spree_purchase_order_items do |t|
      t.references :purchase_order, null: false
      t.references :variant, null: false
      t.integer :quantity_ordered, null: false, default: 0
      t.integer :quantity_received, null: false, default: 0
      t.decimal :unit_cost, precision: 10, scale: 2, null: false, default: 0
      t.timestamps
    end
    add_index :spree_purchase_order_items, [:purchase_order_id, :variant_id],
              unique: true, name: 'idx_purchase_order_items_unique'

    # The purchase order is a new cause flavour for the `received` kind; the
    # unit cost is what those units landed at, which is what a rolling average
    # cost will be computed from.
    add_column :spree_stock_movements, :purchase_order_id, :bigint
    add_index :spree_stock_movements, :purchase_order_id
    add_column :spree_stock_movements, :unit_cost, :decimal, precision: 10, scale: 2
  end
end
