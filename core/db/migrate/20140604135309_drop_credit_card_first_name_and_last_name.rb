class DropCreditCardFirstNameAndLastName < ActiveRecord::Migration[4.2]
  def change
    remove_column :spree_credit_cards, :first_name, :string
    remove_column :spree_credit_cards, :last_name, :string
  end
end
