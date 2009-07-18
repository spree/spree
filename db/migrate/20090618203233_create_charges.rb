# Temporarily redefine the Order object so we can migrate legacy data without problems
# class Order < ActiveRecord::Base  
#   has_many :charges, :order => :position
#   has_many :shipping_charges
#   has_many :tax_charges
# end  

class CreateCharges < ActiveRecord::Migration
  def self.up
    create_table :charges do |t|
      t.references :order
      t.string :type
      t.decimal :amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.string :description
      t.integer :position
      t.timestamps
    end
        
    change_table :orders do |t|
      t.decimal :charge_total, :precision => 8, :scale => 2, :default => 0.0, :null => false      
    end    

    # create shipping and taxation charges for order, then drop columns
    Order.reset_column_information
    
    Order.class_eval do
      def update_totals
        # temporary hack to eliminate problems with migrating legacy data
      end
    end           
    
    Order.all.each do |order|  
      ship_total = order.attributes["ship_amount"] || 0      
      tax_total = order.attributes["tax_amount"] || 0             
      order.shipping_charges.reset
      order.shipping_charges.create(:amount => ship_total, :description => "Shipping") if ship_total > 0
      order.tax_charges.create(:amount => tax_total, :description => "Tax") if tax_total > 0
      order.update_attribute("charge_total", ship_total + tax_total)
    end

    change_table :orders do |t|
      t.remove :ship_amount
      t.remove :tax_amount
    end  
  end

  def self.down
    drop_table :charges    
    change_table :orders do |t|
      t.remove :charge_total
    end  
  end
end
