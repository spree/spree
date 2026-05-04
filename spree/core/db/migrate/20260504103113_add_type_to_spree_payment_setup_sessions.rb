class AddTypeToSpreePaymentSetupSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_payment_setup_sessions, :type, :string
    add_index :spree_payment_setup_sessions, :type
  end
end
