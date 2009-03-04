class CheckoutPresenter < ActivePresenter::Base
  presents :creditcard, {:bill_address => Address}, {:ship_address => Address} 
 
  alias_method :old_initialize, :initialize 
  attr_accessor :order
  attr_accessor :shipping_method
  
  def initialize(args = {})               
    old_initialize(args)
    default_country = Country.find_by_id Spree::Config[:default_country_id]
    bill_address.country ||= default_country
    ship_address.country ||= default_country    
    # credit card needs to use some bill_address attributes
    creditcard.address = bill_address  
    creditcard.first_name = bill_address.firstname
    creditcard.last_name = bill_address.lastname      
  end 
  
  def save              
    # TODO - do not allow save if checkout complete (double post, other user shennaingans)
    # Client side validation should ensure everything is valid, if its not all valid, user must not be done yet
    final_answer = valid?
    self.errors.clear

    saved = false

    ActiveRecord::Base.transaction do
      # clear existing shipments (no orphans please)
      order.shipments.clear
      order.shipments.create(:address => ship_address, :shipping_method => shipping_method)
      if final_answer
        order.complete
        # authorize the credit card and then save (authorize first before number is cleared for security purposes)
        creditcard.order = order
        creditcard.authorize(order.total)
        creditcard.save
      end      
      saved = true
    end
    saved  
  end
end