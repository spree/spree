class AddCheckoutColumnsToSpreeCarts < ActiveRecord::Migration[7.2]
  def change
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
