class AddTypeToSpreePaymentSetupSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_payment_setup_sessions, :type, :string, if_not_exists: true
    add_index :spree_payment_setup_sessions, :type, if_not_exists: true
  end
end
