# This migration comes from spree (originally 20250311105934)
class CreateSpreeGatewayCustomers < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_gateway_customers, if_not_exists: true do |t|
      t.string :profile_id, null: false
      t.bigint :payment_method_id, null: false
      t.bigint :user_id, null: false

      t.timestamps

      t.index ['payment_method_id'], name: 'index_spree_gateway_customers_on_payment_method_id'
      t.index ['user_id', 'payment_method_id'], name: 'index_spree_gateway_customers_on_user_id_and_payment_method_id', unique: true
      t.index ['user_id'], name: 'index_spree_gateway_customers_on_user_id'
    end

    add_column :spree_credit_cards, :gateway_customer_id, :bigint, if_not_exists: true
    add_index :spree_credit_cards, :gateway_customer_id, if_not_exists: true
  end
end
