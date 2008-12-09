class Creditcard < ActiveRecord::Base 
  before_create :filter_sensitive
  belongs_to :order
  has_one :address, :as => :addressable
  has_many :creditcard_payments
  
  # TODO - add before_save to encrypt creditcard number and cvv
  
  # intialize from active_merchant creditcard object  
  def self.new_from_active_merchant(creditcard)
    card = self.new
    card.cc_type = ActiveMerchant::Billing::CreditCard.type?(creditcard.number)
    card.number = creditcard.number
    card.verification_value = creditcard.verification_value
    card.display_number = ActiveMerchant::Billing::CreditCard.mask(creditcard.number) 
    card.month = creditcard.month
    card.year = creditcard.year
    card.first_name = creditcard.first_name
    card.last_name = creditcard.last_name
    card
  end
  
  private
  def filter_sensitive
    self.number = nil unless Spree::Config[:store_cc]
    self.verification_value = nil unless Spree::Config[:store_cvv]
  end

end