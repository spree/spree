class PolymorphicPayments < ActiveRecord::Migration
  def self.up
    # TODO - migrate legacy payments (STI no longer needed)
    remove_column :payments, :type
    remove_column :payments, :creditcard_id
    rename_column :payments, :order_id, :payable_id
    change_table :payments do |t|
      t.string :payable_type
      t.string :payment_method
      t.references :source, :polymorphic => true
    end
    # TODO - migrate legacy creditcards first (associate them with a payment before killing association with checkout, etc)
    change_table :creditcards do |t|
      t.remove :checkout_id
    end 
  end

  def self.down
    # no going back!
  end
end
