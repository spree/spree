class CreateTypedAdjustmentTables < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_tax_lines do |t|
      t.references :order, null: false
      t.references :tax_rate, null: false
      t.references :line_item
      # Points at spree_shipments until the Fulfillment rename lands
      # (docs/plans/6.0-split-adjustments.md, Resolved Question 4)
      t.references :fulfillment
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :label, null: false
      # No DB default — the model owns the default (false)
      t.boolean :included, null: false
      t.timestamps
    end

    add_index :spree_tax_lines, [:line_item_id, :tax_rate_id], unique: true,
              where: 'line_item_id IS NOT NULL', name: 'idx_tax_lines_line_item_rate'
    add_index :spree_tax_lines, [:fulfillment_id, :tax_rate_id], unique: true,
              where: 'fulfillment_id IS NOT NULL', name: 'idx_tax_lines_fulfillment_rate'

    create_table :spree_discount_lines do |t|
      t.references :order, null: false
      t.references :promotion_action
      t.references :promotion
      t.references :line_item
      t.references :fulfillment
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :label, null: false
      t.string :kind
      t.timestamps
    end

    add_index :spree_discount_lines, [:line_item_id, :promotion_action_id], unique: true,
              where: 'line_item_id IS NOT NULL', name: 'idx_discount_lines_line_item_action'
    add_index :spree_discount_lines, [:fulfillment_id, :promotion_action_id], unique: true,
              where: 'fulfillment_id IS NOT NULL', name: 'idx_discount_lines_fulfillment_action'

    create_table :spree_fees do |t|
      t.references :order, null: false
      t.references :line_item
      t.references :fulfillment
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :label, null: false
      t.string :kind, null: false
      t.timestamps
    end

    add_index :spree_fees, [:order_id, :kind]

    # Order total formula gains fee_total (Resolved Question 3). default: 0
    # matches the existing total columns and is required to add NOT NULL to a
    # populated table.
    add_column :spree_orders, :fee_total, :decimal, precision: 10, scale: 2, null: false, default: 0
  end
end
