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
    self.cc_type = ActiveMerchant::Billing::CreditCard.type?(creditcard.number)
    self.number = creditcard.number if Spree::Config[:store_cc]
    self.display_number = creditcard.display_number 
    self.month = creditcard.month
    self.year = creditcard.year
    self.first_name = creditcard.first_name
    self.last_name = creditcard.last_name
  end
  
  def find_authorization
    #find the transaction associated with the original authorization/capture 
    cc = order.creditcard_payment
    cc.txns.find(:first, 
                 :conditions => ["txn_type = ? or txn_type = ?", CreditcardTxn::TxnType::AUTHORIZE, CreditcardTxn::TxnType::CAPTURE],
                 :order => 'created_at DESC')
  end
end