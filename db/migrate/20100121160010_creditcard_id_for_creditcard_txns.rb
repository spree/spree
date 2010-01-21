class CreditcardIdForCreditcardTxns < ActiveRecord::Migration
  def self.up
    add_column "creditcard_txns", "creditcard_id", :integer
  end

  def self.down
    remove_column "creditcard_txns", "creditcard_id"
  end
end
