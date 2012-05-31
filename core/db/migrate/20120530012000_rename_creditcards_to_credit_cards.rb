class RenameCreditcardsToCreditCards < ActiveRecord::Migration
  def change
    rename_table :spree_creditcards, :spree_credit_cards
    execute("UPDATE spree_payments SET source_type = 'Spree::CreditCard' WHERE source_type = 'Spree::Creditcard'")
  end

  def down
    execute("UPDATE spree_payments SET source_type = 'Spree::Creditcard' WHERE source_type = 'Spree::CreditCard'")
    rename_table :spree_credit_cards, :spree_creditcards
  end
end
