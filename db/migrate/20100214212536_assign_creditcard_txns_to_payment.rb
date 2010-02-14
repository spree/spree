class AssignCreditcardTxnsToPayment < ActiveRecord::Migration
  def self.up
    add_column "creditcard_txns", "payment_id", :integer  
    remove_column "creditcard_txns", "creditcard_payment_id"
  end

  def self.down
    remove_column "creditcard_txns", "payment_id"
    add_column "creditcard_txns", "creditcard_payment_id", :integer  
  end
end
