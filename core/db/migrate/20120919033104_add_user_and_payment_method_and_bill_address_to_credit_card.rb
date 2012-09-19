class AddUserAndPaymentMethodAndBillAddressToCreditCard < ActiveRecord::Migration
  def change
    add_column :spree_credit_cards, :user_id, :integer
    add_column :spree_credit_cards, :payment_method_id, :integer
    add_column :spree_credit_cards, :bill_address_id, :integer

    # Name was changed in previous migration, so it still thinks it's spree_creditcard 
    # if all migrations are run (as with test module)
    Spree::CreditCard.reset_table_name 

    Spree::CreditCard.where('gateway_customer_profile_id IS NOT NULL').find_each do |credit_card|
      next unless payment = credit_card.payments.first
      credit_card.user = payment.order.try(:user)
      credit_card.payment_method = payment.payment_method
      credit_card.bill_address = payment.order.try(:bill_address)
      unless credit_card.save
        puts "Unable to migrate data to credit card #{credit_card.id}: #{credit_card.errors.inspect}"
      end
    end
  end
end
