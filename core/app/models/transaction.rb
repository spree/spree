class Transaction < ActiveRecord::Base
  belongs_to :payment

  validates :amount, :numericality => true

end