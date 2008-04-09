require 'shipping/flat_rate'
require 'tax/sales_tax'

module CheckoutHelper
  CREDIT_CARD_TYPES = [
    ["Visa", "visa"], 
    ["Master Card", "master"],
    ["Discover", "discover"], 
    ["American Express", "american_express"]
  ].freeze
  
  #for some reason i had to define a method ... apparently constants are not mixed in
  #in the view helper (not sure but that's my guess)
  def credit_card_types
    CREDIT_CARD_TYPES
  end  
end
