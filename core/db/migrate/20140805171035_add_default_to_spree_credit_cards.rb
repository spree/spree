class AddDefaultToSpreeCreditCards < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_credit_cards, :default, :boolean, null: false, default: false
  end
end
