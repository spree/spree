class RenameSpreePaymentsStateToStatus < ActiveRecord::Migration[8.1]
  def change
    rename_column :spree_payments, :state, :status
  end
end
