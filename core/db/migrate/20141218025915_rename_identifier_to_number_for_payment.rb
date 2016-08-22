class RenameIdentifierToNumberForPayment < ActiveRecord::Migration[4.2]
  def change
    rename_column :spree_payments, :identifier, :number
  end
end
