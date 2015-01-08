class CreateSpreePaymentCaptureEvents < ActiveRecord::Migration
  def change
    create_table :spree_payment_capture_events do |t|
      t.decimal :amount, precision: 10, scale: 2, default: 0.0
      t.integer :payment_id

      t.timestamps null: false
    end

    add_index :spree_payment_capture_events, :payment_id
  end
end
