class Creditcard < ActiveRecord::Base #ActiveMerchant::Billing::CreditCard
  belongs_to :order
  has_one :address, :as => :addressable
  
  # intialize from active_merchant creditcard object  
  def self.new_from_active_merchant(creditcard)
    card = self.new
    card.cc_type = ActiveMerchant::Billing::CreditCard.type?(creditcard.number)
    card.number = creditcard.number #if Spree::Config[:store_cc]
    card.verification_value = creditcard.verification_value #if Spree::Config[:store_cc]
    card.display_number = ActiveMerchant::Billing::CreditCard.mask(creditcard.number) #creditcard.display_number 
    card.month = creditcard.month
    card.year = creditcard.year
    card.first_name = creditcard.first_name
    card.last_name = creditcard.last_name
    card
  end

end