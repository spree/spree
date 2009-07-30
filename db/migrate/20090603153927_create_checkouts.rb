class Order < ActiveRecord::Base  
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"  
  has_many :shipments
end

class CreateCheckouts < ActiveRecord::Migration
  def self.up
    create_table :checkouts do |t|
      t.references :order
      t.references :shipping_method
      t.string :email
      t.string :ip_address
      t.text :special_instructions
      t.integer :bill_address_id
      t.integer :ship_address_id
      t.datetime :completed_at
      t.timestamps
    end

    change_table :creditcards do |t|
      t.references :checkout
    end                     

    Checkout.reset_column_information
    Creditcard.reset_column_information

    Checkout.class_eval do
      # temporarily disable the charge stuff since its interfering with this migration
      def update_charges
      end
    end
        
    # move address, etc. from order to checkout
    Order.all.each do |order|             
      shipping_method = order.shipments.last.shipping_method if order.shipments.present?  
      completed_at = order.attributes["created_at"] if order.attributes["checkout_complete"] 
      creditcard = Creditcard.find_by_order_id(order.id)
      checkout = Checkout.create(:order => order, 
                                 :bill_address => order.bill_address, 
                                 :ship_address => order.ship_address, 
                                 :email => order.attributes["email"],
                                 :special_instructions => order.attributes["special_instructions"],
                                 :ip_address => order.attributes["ip_address"],
                                 :created_at => order.attributes["created_at"],
                                 :completed_at => completed_at, 
                                 :shipping_method => shipping_method)
      creditcard.update_attribute("checkout_id", checkout.id) if creditcard
    end

    change_table :orders do |t|
      t.remove :special_instructions
      t.remove :bill_address_id
      t.remove :ship_address_id
      t.remove :email
      t.remove :ip_address  
      t.remove :checkout_complete
    end

    change_table :creditcards do |t|
      t.remove :order_id
    end
  end

  def self.down
    drop_table :checkouts
  end
end
