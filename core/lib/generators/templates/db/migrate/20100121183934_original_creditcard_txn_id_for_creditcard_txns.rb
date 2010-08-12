class OriginalCreditcardTxnIdForCreditcardTxns < ActiveRecord::Migration
  def self.up
    add_column "creditcard_txns", "original_creditcard_txn_id", :integer
  end

  def self.down
    remove_column "creditcard_txns", "original_creditcard_txn_id"
  end
end
