class AssignCreditcardTxnsToPayment < ActiveRecord::Migration
  def self.up
    add_column "creditcard_txns", "payment_id", :integer
    ActiveRecord::Base.connection.select_all("SELECT * FROM creditcard_txns").each do |txn_attrs|
      if creditcard = Creditcard.find_by_id(txn_attrs["creditcard_id"]) and creditcard.payments.first
        execute "UPDATE creditcard_txns SET payment_id = #{creditcard.payments.first.id} WHERE id = #{txn_attrs['id']}"
      end
    end
    remove_column "creditcard_txns", "creditcard_payment_id"
  end

  def self.down
    remove_column "creditcard_txns", "payment_id"
    add_column "creditcard_txns", "creditcard_payment_id", :integer
  end
end
