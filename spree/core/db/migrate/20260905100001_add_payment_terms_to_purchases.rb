class AddPaymentTermsToPurchases < ActiveRecord::Migration[8.1]
  def change
    # The buyer's side of the deal, frozen at placement: whether the whole
    # total is due now or a deposit is, and what to call the rest. Nil is
    # pay-in-full, which is every order today.
    %i[spree_carts spree_orders].each do |table|
      if connection.adapter_name.match?(/postgres/i)
        add_column table, :payment_terms, :jsonb
      else
        add_column table, :payment_terms, :json
      end
    end
  end
end
