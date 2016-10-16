class AddCvvResultCodeAndCvvResultMessageToSpreePayments < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_payments, :cvv_response_code, :string
    add_column :spree_payments, :cvv_response_message, :string
  end
end
