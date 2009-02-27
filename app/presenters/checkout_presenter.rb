class CheckoutPresenter < ActivePresenter::Base
  presents :creditcard, {:bill_address => Address}, {:ship_address => Address}
 
  alias_method :old_initialize, :initialize 
  
  def initialize(args = {})               
    old_initialize(args)
    default_country = Country.find_by_id Spree::Config[:default_country_id]
    bill_address.country ||= default_country
    ship_address.country ||= default_country    
  end
end