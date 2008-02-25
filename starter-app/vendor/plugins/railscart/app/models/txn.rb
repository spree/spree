class Txn < ActiveRecord::Base
  belongs_to :credit_card
  validates_numericality_of :amount
  #validates_presence_of :cc_number
  
  enumerable_constant :txn_type, :constants => TXN_TYPES
end