class PolymorphicPayments < ActiveRecord::Migration
  def self.up
    remove_column :payments, :type
    remove_column :payments, :creditcard_id
    rename_column :payments, :order_id, :payable_id
    change_table :payments do |t|
      t.string :payable_type
      t.string :payment_method
      t.references :source, :polymorphic => true
    end
    execute "UPDATE payments SET payable_type = 'Order'"

    Creditcard.all.each do |creditcard|
      if checkout = Checkout.find_by_id(creditcard.checkout_id) and checkout.order
        if payment = checkout.order.payments.first
          execute "UPDATE payments SET source_type = 'Creditcard', source_id = #{creditcard.id} WHERE id = #{payment.id}"
        end
      end
    end

    change_table :creditcards do |t|
      t.remove :checkout_id
    end 
  end

  def self.down
    # no going back!
  end
end
