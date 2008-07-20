class Txn < ActiveRecord::Base
  belongs_to :transactable, :polymorphic => true
  validates_numericality_of :amount
  #validates_presence_of :cc_number
  
  enumerable_constant :txn_type, :constants => TXN_TYPES
  
  named_scope :credit_card, lambda {|transactable| {:conditions => ["transactable_type = 'CreditCard' and transactable_id = ?", transactable]}}
end