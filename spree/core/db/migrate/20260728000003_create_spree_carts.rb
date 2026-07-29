class CreateSpreeCarts < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_carts do |t|
      t.references :store, null: false
      t.references :market, null: false
      t.references :channel, null: false
      t.references :customer, null: true
      t.string :currency, null: false
      t.string :locale
      t.string :email
      t.references :ship_address, null: true, index: false
      t.references :bill_address, null: true, index: false
      t.boolean :accept_marketing
      t.text :special_instructions
      t.string :last_ip_address
      t.string :token, null: false
      t.integer :lock_version, default: 0
      t.datetime :completed_at
      t.datetime :completing_at
      t.string :coupon_code
      t.references :gift_card, null: true

      t.decimal :item_total, precision: 10, scale: 2, default: 0.0
      t.decimal :adjustment_total, precision: 10, scale: 2, default: 0.0
      t.decimal :included_tax_total, precision: 10, scale: 2, default: 0.0
      t.decimal :additional_tax_total, precision: 10, scale: 2, default: 0.0
      t.decimal :taxable_adjustment_total, precision: 10, scale: 2, default: 0.0
      t.decimal :non_taxable_adjustment_total, precision: 10, scale: 2, default: 0.0
      t.decimal :discount_total, precision: 10, scale: 2, default: 0.0
      t.decimal :fee_total, precision: 10, scale: 2, default: 0.0
      t.decimal :delivery_total, precision: 10, scale: 2, default: 0.0
      t.decimal :total, precision: 10, scale: 2, default: 0.0
      t.decimal :payment_total, precision: 10, scale: 2, default: 0.0
      t.integer :total_quantity, default: 0
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end
    add_index :spree_carts, :token, unique: true
    add_index :spree_carts, :completed_at
    add_index :spree_carts, :updated_at

    add_reference :spree_line_items, :cart, null: true, if_not_exists: true

    # The completion idempotency key — one order per cart, enforced by the DB.
    add_reference :spree_orders, :cart, null: true, index: { unique: true }, if_not_exists: true

    rename_column :spree_orders, :payment_state, :payment_status
    add_index :spree_orders, :payment_status

    rename_column :spree_orders, :state_lock_version, :lock_version
  end
end
