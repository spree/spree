module Spree
  module Api
    module V3
      class PaymentSerializer < BaseSerializer
        attributes :id, :state, :payment_method_id, :response_code, :number,
                   :cvv_response_code, :cvv_response_message,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :amount do |payment|
          payment.amount.to_f
        end

        attribute :display_amount do |payment|
          payment.display_amount.to_s
        end

        attribute :payment_method_name do |payment|
          payment.payment_method&.name
        end
      end
    end
  end
end
