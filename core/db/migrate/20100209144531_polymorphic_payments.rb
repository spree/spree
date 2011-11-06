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

    Spree::Creditcard.table_name = 'creditcards'

    Spree::Creditcard.all.each do |creditcard|
      if checkout = Checkout.find_by_id(creditcard.checkout_id) and checkout.order
        if payment = checkout.order.payments.first
          execute "UPDATE payments SET source_type = 'Creditcard', source_id = #{creditcard.id} WHERE id = #{payment.id}"
        end
      end
    end

    Spree::Creditcard.table_name = 'spree_creditcards'

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
