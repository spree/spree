class OriginalCreditcardTxnIdForCreditcardTxns < ActiveRecord::Migration
  def change
    add_column :creditcard_txns, :original_creditcard_txn_id, :integer
  end
end
