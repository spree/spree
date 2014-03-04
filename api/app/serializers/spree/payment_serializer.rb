module Spree
  class PaymentSerializer < ActiveModel::Serializer
    attributes :id, :amount, :source_type, :source_id, :display_amount,
               :payment_method_id, :response_code, :state, :avs_response,
               :created_at, :updated_at
    has_one :payment_method
  end
end