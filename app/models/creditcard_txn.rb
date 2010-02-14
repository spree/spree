class CreditcardTxn < ActiveRecord::Base
  belongs_to :payment
  belongs_to :creditcard

  # For refunds and voids, this association will store the original transaction that's being refunded or voided
  belongs_to :original_txn, :class_name => 'CreditcardTxn', :foreign_key => 'original_creditcard_txn_id'
  has_many :creditcard_txns, :foreign_key => 'original_creditcard_txn_id', :order => 'created_at'

  validates_numericality_of :amount

  named_scope :original, :conditions => 'original_creditcard_txn_id IS NULL'
  
  enumerable_constant :txn_type, :constants => [:authorize, :capture, :purchase, :void, :credit]
  
  def txn_type_name
    TxnType.from_value(txn_type)
  end

end