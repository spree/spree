class RenameCreditcardsToCreditCards < ActiveRecord::Migration
  def change
    rename_table :spree_creditcards, :spree_credit_cards
  end
end
