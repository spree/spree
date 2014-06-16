class RemoveUncapturedAmountFromSpreePayments < ActiveRecord::Migration
  def change
    remove_column :spree_payments, :uncaptured_amount
  end
end
