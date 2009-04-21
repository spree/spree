class CreditcardPayment < Payment
  has_many :creditcard_txns
  belongs_to :creditcard
  accepts_nested_attributes_for :creditcard
  
  alias :txns :creditcard_txns
  
  def find_authorization
    #find the transaction associated with the original authorization/capture 
    txns.find(:first, 
              :conditions => ["txn_type = ? AND response_code IS NOT NULL", CreditcardTxn::TxnType::AUTHORIZE],
              :order => 'created_at DESC')
  end 
  
  def can_capture?
    txns.last == find_authorization
  end
end