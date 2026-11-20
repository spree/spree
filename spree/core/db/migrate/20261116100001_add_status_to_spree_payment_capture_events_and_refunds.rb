# Statuses are added empty: an empty status reads as completed until the
# backfill_settlement_statuses upgrade step fills it in.
class AddStatusToSpreePaymentCaptureEventsAndRefunds < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_payment_capture_events, bulk: true do |t|
      t.string :status
      t.string :transaction_id
      t.index :transaction_id
    end

    change_table :spree_refunds, bulk: true do |t|
      t.string :status
      t.string :failure_reason
      t.index :transaction_id
    end
  end
end
