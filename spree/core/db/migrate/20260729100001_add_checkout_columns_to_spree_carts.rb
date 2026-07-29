class AddCheckoutColumnsToSpreeCarts < ActiveRecord::Migration[7.2]
  def change
    change_table :spree_carts do |t|
      t.decimal :item_total, precision: 10, scale: 2
      t.decimal :adjustment_total, precision: 10, scale: 2
      t.decimal :included_tax_total, precision: 10, scale: 2
      t.decimal :additional_tax_total, precision: 10, scale: 2
      t.decimal :taxable_adjustment_total, precision: 10, scale: 2
      t.decimal :non_taxable_adjustment_total, precision: 10, scale: 2
      t.decimal :promo_total, precision: 10, scale: 2
      t.decimal :fee_total, precision: 10, scale: 2
      t.decimal :delivery_total, precision: 10, scale: 2
      t.decimal :total, precision: 10, scale: 2
      t.decimal :payment_total, precision: 10, scale: 2
      t.integer :item_count
      t.string :coupon_code
    end

    # Owner pattern: promotion connections and payment sessions are created
    # during checkout (cart-owned), copied/re-pointed at completion.
    add_reference :spree_order_promotions, :cart, null: true
    add_reference :spree_payment_sessions, :cart, null: true
    add_reference :spree_payments, :cart, null: true
    add_reference :spree_stock_reservations, :cart, null: true
    add_reference :spree_coupon_codes, :cart, null: true

    # The checkout state machine is gone — checkout progression lives on the
    # Cart (Checkout::Requirements); Order keeps only status.
    remove_column :spree_orders, :state, :string
  end
end
