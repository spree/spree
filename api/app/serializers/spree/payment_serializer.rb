module Spree
  class PaymentSerializer < ActiveModel::Serializer
    attributes :id, :amount
    has_one :payment_method
  end
end