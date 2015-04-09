module Spree
  class PaymentSerializer < ActiveModel::Serializer
    attributes :id, :source_type, :source_id, :amount, :display_amount,
               :payment_method_id, :response_code, :state, :avs_response,
               :created_at, :updated_at, :source

    def source
      return object.source.attributes
    end
  end
end
