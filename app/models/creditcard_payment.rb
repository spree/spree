class CreditcardPayment < ActiveRecord::Base
  has_many :creditcard_txns
  belongs_to :order
  has_one :address, :as => :addressable
  
  alias :txns :creditcard_txns

  # Sets the properties of the payment based on the creditcard attributes.  The cc information is also stored 
  # (in memory) so that the card can be authorized before saving the payment.  The credticard number will only 
  # be saved in the payment record if you specify this as a preference (disabled by default.)  If you do decide 
  # to store the creditcard number be sure to use PGP encryption and store the private key on a separate server.  
  # One use case for this would be to store the creditcard information if the gateway is down and then retry the 
  # authorization later.
  def creditcard=(creditcard)
    @creditcard = creditcard
  end
  
  def authorize
    # to be implemented by an extension (default is payment_gateway extension which ships with spree)
  end

  def capture
    # to be implemented by an extension (default is payment_gateway extension which ships with spree)
  end
  
  def void
    # to be implemented by an extension (default is payment_gateway extension which ships with spree)
  end
  
  def find_authorization
    #find the transaction associated with the original authorization/capture 
    cc = order.creditcard_payment
    cc.txns.find(:first, 
                 :conditions => ["txn_type = ? or txn_type = ?", CreditcardTxn::TxnType::AUTHORIZE, CreditcardTxn::TxnType::CAPTURE],
                 :order => 'created_at DESC')
  end
  
  # creates a new instance of CreditCard using the active merchant version
  def self.new_from_active_merchant(cc)
    card = self.new
    card.number = cc.number if Spree::Config[:store_cc]
    card.cc_type = cc.type
    card.display_number = cc.display_number 
    card.verification_value = cc.verification_value if Spree::Config[:store_cc]
    card.month = cc.month
    card.year = cc.year
    card.first_name = cc.first_name
    card.last_name = cc.last_name
    card
  end
end