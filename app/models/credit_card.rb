# ActiveMerchant supplies a credit card class but it is not implemented as an ActiveRecord object in order to 
# discourage storing the information in the database.  It is, however, both safe and desirable to store this 
# information provided the necessary precautions are taken.  It is safe if you use PGP encryption to encrypt
# the number and verification code.  The private key, however, must be stored securely on a separate physical machine.  
# It is desirable, because your gateway could go down for several minutes or even hours and you may want to run 
# these transactions later when the gateway becomes available again.
class CreditCard < ActiveRecord::Base
  has_many :txns, :as => :transactable
  belongs_to :order
  
  # creates a new instance of CreditCard using the active merchant version
  def self.new_from_active_merchant(cc)
    card = self.new
    card.number = cc.number
    card.cc_type = cc.type
    card.display_number = cc.display_number
    card.verification_value = cc.verification_value
    card.month = cc.month
    card.year = cc.year
    card.first_name = cc.first_name
    card.last_name = cc.last_name
    card
  end
end