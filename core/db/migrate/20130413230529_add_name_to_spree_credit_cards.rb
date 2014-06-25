class AddNameToSpreeCreditCards < ActiveRecord::Migration
  def change
    add_column :spree_credit_cards, :name, :string
  end
end
