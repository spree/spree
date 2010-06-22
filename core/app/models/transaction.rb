class Transaction < ActiveRecord::Base
  belongs_to :payment

  validates_numericality_of :amount

end