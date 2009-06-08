class CreditcardPayment < Payment
  has_many :creditcard_txns
  belongs_to :creditcard
  accepts_nested_attributes_for :creditcard
  
  alias :txns :creditcard_txns
  
  def can_capture?
    txns.present? and txns.last == authorization
  end
  
  def capture
    return unless can_capture?
    original_auth = authorization
    creditcard.capture(original_auth)
    update_attribute("amount", original_auth.amount)
  end
  
  def authorization
    #find the transaction associated with the original authorization/capture 
    txns.find(:first, 
              :conditions => ["txn_type = ? AND response_code IS NOT NULL", CreditcardTxn::TxnType::AUTHORIZE.to_s],
              :order => 'created_at DESC')
  end 
  
end