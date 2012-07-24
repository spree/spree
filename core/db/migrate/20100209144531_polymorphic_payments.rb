# Legacy table support
class Checkout < ActiveRecord::Base; end;

class PolymorphicPayments < ActiveRecord::Migration
  def up
    remove_column :payments, :type
    remove_column :payments, :creditcard_id
    rename_column :payments, :order_id, :payable_id
    change_table :payments do |t|
      t.string :payable_type, :payment_method
      t.references :source, :polymorphic => true
    end
    execute "UPDATE payments SET payable_type = 'Order'"

    Spree::CreditCard.table_name = 'creditcards'

    Spree::CreditCard.all.each do |credit_card|
      if checkout = Checkout.find_by_id(credit_card.checkout_id) && checkout.order
        if payment = checkout.order.payments.first
          execute "UPDATE payments SET source_type = 'CreditCard', source_id = #{credit_card.id} WHERE id = #{payment.id}"
        end
      end
    end

    Spree::CreditCard.table_name = 'spree_creditcards'

    remove_column :creditcards, :checkout_id
  end

  def down
    add_column :creditcards, :checkout_id, :integer
    change_table :payments do |t|
      t.remove :payable_type
      t.remove :payment_method
      t.remove :source_id
      t.remove :source_type
    end
    rename_column :payments, :payable_id, :order_id
    add_column :payments, :creditcard_id, :integer
    add_column :payments, :type, :string
  end
end
