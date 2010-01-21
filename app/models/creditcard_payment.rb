class CreditcardPayment < Payment
  has_many :creditcard_txns
  belongs_to :creditcard
  belongs_to :order
  accepts_nested_attributes_for :creditcard
  accepts_nested_attributes_for :order

  alias :txns :creditcard_txns

end