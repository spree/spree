class CreditcardTxn < ActiveRecord::Base
  belongs_to :creditcard
  belongs_to :creditcard_payment

  # For refunds and voids, this association will store the original transaction that's being refunded or voided
  belongs_to :original_txn, :class_name => 'CreditcardTxn', :foreign_key => 'original_creditcard_txn_id'
  has_many :creditcard_txns, :foreign_key => 'original_creditcard_txn_id', :order => 'created_at'

  validates_numericality_of :amount
  after_create :update_payments
  
  named_scope :original, :conditions => 'original_creditcard_txn_id IS NULL'
  
  enumerable_constant :txn_type, :constants => [:authorize, :capture, :purchase, :void, :credit]
  
  def txn_type_name
    TxnType.from_value(txn_type)
  end
  

  private
  
    def update_payments
      case txn_type
        when CreditcardTxn::TxnType::PURCHASE, CreditcardTxn::TxnType::CAPTURE
          create_creditcard_payment
        when CreditcardTxn::TxnType::VOID
          delete_creditcard_payment
        when CreditcardTxn::TxnType::CREDIT
          update_creditcard_payment
      end
      save
    end
  
    def create_creditcard_payment
      if txn_type == CreditcardTxn::TxnType::PURCHASE
        update_attribute(:creditcard_payment, CreditcardPayment.create!(:order => creditcard.checkout.order, :amount => amount, :creditcard => creditcard))
      else
        # for capture transactions, payment is assigned to the original authorize transaction instead
        original_txn.update_attribute(:creditcard_payment, CreditcardPayment.create!(:order => creditcard.checkout.order, :amount => amount, :creditcard => creditcard))
      end
    end
  
    def update_creditcard_payment
      if original_txn and original_txn.creditcard_payment
        original_txn.creditcard_payment.update_attribute(:amount, original_txn.creditcard_payment.amount + amount)
      end
    end
  
    def delete_creditcard_payment
      if original_txn and original_txn.creditcard_payment
        original_txn.creditcard_payment.destroy
      end
    end

end