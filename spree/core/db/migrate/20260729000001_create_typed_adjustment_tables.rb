class CreateTypedAdjustmentTables < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_tax_lines do |t|
      # Owner — exactly one of cart/order (enforced at model level)
      t.references :cart, null: true
      t.references :order, null: true

      # Source — nil for externally-computed tax; snapshots keep rows self-describing
      t.references :tax_rate, null: true

      # Adjustable — exactly one (enforced at model level)
      t.references :line_item, null: true
      t.references :fulfillment, null: true
      t.references :fee, null: true

      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :rate, precision: 8, scale: 5, null: false
      t.string :label, null: false
      t.boolean :included, null: false
      t.string :provider_id
      if t.respond_to?(:jsonb)
        t.jsonb :data
        t.jsonb :metadata
      else
        t.json :data
        t.json :metadata
      end

      t.timestamps
    end

    create_table :spree_discounts do |t|
      t.references :cart, null: true
      t.references :order, null: true

      # Source — nullified on promotion deletion; code/value snapshots keep history meaningful
      t.references :promotion_action, null: true
      t.references :promotion, null: true

      # Adjustable — exactly one (enforced at model level)
      t.references :line_item, null: true
      t.references :fulfillment, null: true

      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :label, null: false
      t.string :kind, null: false
      t.string :code
      t.decimal :value, precision: 10, scale: 2
      t.string :value_type
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps

      t.check_constraint 'amount <= 0', name: 'chk_spree_discounts_amount_nonpositive'
    end
    add_index :spree_discounts, :code

    create_table :spree_fees do |t|
      t.references :cart, null: true
      t.references :order, null: true, index: false

      # Adjustable — both nil means an order-level fee (payment surcharge, COD, ...)
      t.references :line_item, null: true
      t.references :fulfillment, null: true

      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :label, null: false
      t.string :kind, null: false
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps

      t.check_constraint 'amount >= 0', name: 'chk_spree_fees_amount_nonnegative'
    end
    add_index :spree_fees, [:order_id, :kind]

    add_column :spree_orders, :fee_total, :decimal, precision: 10, scale: 2
  end
end
