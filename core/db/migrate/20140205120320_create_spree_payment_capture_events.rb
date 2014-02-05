class CreateSpreePaymentCaptureEvents < ActiveRecord::Migration
  def change
    create_table :spree_payment_capture_events do |t|
      t.integer :amount
      t.integer :payment_id

      t.timestamps
    end

    add_index :spree_payment_capture_events, :payment_id
  end
end
