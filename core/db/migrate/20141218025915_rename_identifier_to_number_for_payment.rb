class RenameIdentifierToNumberForPayment < ActiveRecord::Migration
  def change
    rename_column :spree_payments, :identifier, :number
  end
end
