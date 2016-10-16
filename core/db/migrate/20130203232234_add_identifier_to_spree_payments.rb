class AddIdentifierToSpreePayments < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_payments, :identifier, :string
  end
end
