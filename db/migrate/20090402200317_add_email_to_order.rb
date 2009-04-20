class AddEmailToOrder < ActiveRecord::Migration
  def self.up        
    change_table :orders do |t|
      t.string :email
    end       
    Order.reset_column_information
    # update legacy orders
    Order.find(:all, :include => :user, :conditions => "checkout_complete IS NOT NULL").each do |order|
      order.email = order.user.email
      order.save
    end
  end

  def self.down      
    change_table :orders do |t|
      t.remove :email
    end    
  end
end
