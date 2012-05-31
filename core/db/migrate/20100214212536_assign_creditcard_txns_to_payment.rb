class AssignCreditcardTxnsToPayment < ActiveRecord::Migration
  def up
    add_column :creditcard_txns, :payment_id, :integer

    # Temporarily set back to creditcards
    Spree::CreditCard.table_name = 'creditcards'

    ActiveRecord::Base.connection.select_all('SELECT * FROM creditcard_txns').each do |txn_attrs|
      if credit_card = Spree::CreditCard.find_by_id(txn_attrs['creditcard_id']) && credit_card.payments.first
        execute "UPDATE creditcard_txns SET payment_id = #{credit_card.payments.first.id} WHERE id = #{txn_attrs['id']}"
      end
    end

    Spree::CreditCard.table_name = 'spree_creditcards'

    remove_column :creditcard_txns, :creditcard_payment_id
  end

  def down
    remove_column :creditcard_txns, :payment_id
    add_column    :creditcard_txns, :creditcard_payment_id, :integer
  end
end
