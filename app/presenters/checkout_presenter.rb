class CheckoutPresenter < ActivePresenter::Base
  presents :creditcard, {:bill_address => Address}, {:ship_address => Address} 

  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information 
  
  alias_method :old_initialize, :initialize 
  attr_accessor :order
  attr_accessor :shipping_method
  attr_accessor :order_hash   
  attr_accessor :final_answer
  
  def initialize(args = {})               
    old_initialize(args)
    default_country = Country.find_by_id Spree::Config[:default_country_id]
    bill_address.country ||= default_country
    ship_address.country ||= default_country    
    # credit card needs to use some bill_address attributes
    creditcard.address = bill_address  
    creditcard.first_name = bill_address.firstname
    creditcard.last_name = bill_address.lastname   
    self.order_hash = {}   
  end 
  
  def save           
    return false if final_answer and not valid?
    saved = false
    ActiveRecord::Base.transaction do
      # clear existing shipments (no orphans please)                             
      order.shipments.clear
      # clear existing addresses, eventually this won't be necessary (we'll have an address book)
      order.user.addresses.clear
      
      order.user.addresses << bill_address.clone
      
      order.shipments.create(:address => ship_address, :shipping_method => shipping_method)
      
      order.ship_amount = order.shipment.shipping_method.calculate_shipping(order.shipment) if order.shipment and order.shipment.shipping_method
      order.tax_amount = order.calculate_tax
      order.save
      
      if final_answer
        # authorize the credit card and then save (authorize first before number is cleared for security purposes)
        creditcard.order = order
        creditcard.authorize(order.total)
        creditcard.save
        order.complete
      end      
      saved = true
    end  
    # populate the order hash  
    
    order_hash[:ship_amount] = number_to_currency(order.ship_amount)
    order_hash[:tax_amount] = number_to_currency(order.tax_amount)
    order_hash[:order_total] = number_to_currency(order.total)
    order_hash[:ship_method] = order.shipment.shipping_method.name if order.shipment and order.shipment.shipping_method
    saved  
  end
end