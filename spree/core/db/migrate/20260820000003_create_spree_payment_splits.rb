class CreateSpreePaymentSplits < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_payment_splits do |t|
      t.references :payment, null: false, index: false
      t.references :order, null: false

      # This child order's share of that one payment. Captures and refunds on a
      # child update its own row and never a sibling's — which is the whole
      # reason the share is a record rather than a proportion computed on read.
      t.decimal :authorized_amount, precision: 10, scale: 2, null: false, default: 0
      t.decimal :captured_amount, precision: 10, scale: 2, null: false, default: 0
      t.decimal :refunded_amount, precision: 10, scale: 2, null: false, default: 0
      t.string :currency, null: false

      t.timestamps
    end

    # One share per (payment, order), so a replayed split cannot write a second.
    add_index :spree_payment_splits, [:payment_id, :order_id], unique: true
  end
end
