class CreditcardTxn < ActiveRecord::Base
  belongs_to :creditcard_payment
  validates_numericality_of :amount
  
  enumerable_constant :txn_type, :constants => [:authorize, :capture, :purchase, :void, :credit]
  
  def creditcard
    creditcard_payment.creditcard
  end
  
end