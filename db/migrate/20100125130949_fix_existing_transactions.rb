class FixExistingTransactions < ActiveRecord::Migration
  def self.up
    CreditcardTxn.all.each do |txn|
      if txn.creditcard_payment and txn.creditcard_payment.order
        txn.creditcard = txn.creditcard_payment.order.checkout.creditcard
        txn.save
      end
    end
  end

  def self.down
  end
end
