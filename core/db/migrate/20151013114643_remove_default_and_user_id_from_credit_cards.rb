class RemoveDefaultAndUserIdFromCreditCards < ActiveRecord::Migration
  def change
    remove_column :spree_credit_cards, :default, :boolean
    remove_column :spree_credit_cards, :user_id, :integer
  end
end
