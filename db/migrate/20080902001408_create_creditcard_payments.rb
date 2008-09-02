class CreateCreditcardPayments < ActiveRecord::Migration
  def self.up
    rename_table :credit_cards, :creditcard_payments
    rename_table :credit_card_txns, :creditcard_txns
    
    change_table :creditcard_payments do |t|
      t.remove :verification_value
    end    
    
    change_table :creditcard_txns do |t|
      t.rename :credit_card_id, :creditcard_payment_id
    end
  end

  def self.down
  end
end
