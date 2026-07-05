module Spree
  module Api
    module V3
      class PaymentSerializer < BaseSerializer
        typelize status: :string, payment_method_id: :string, response_code: [:string, nullable: true],
                 number: :string, amount: [:string, nullable: true], display_amount: [:string, nullable: true],
                 source_type: [:string, nullable: true, enum: %w[credit_card store_credit payment_source]],
                 source_id: [:string, nullable: true],
                 source: 'CreditCard | StoreCredit | PaymentSource | null'

        attribute :payment_method_id do |payment|
          payment.payment_method&.prefixed_id
        end

        attributes :response_code, :number

        # Nulled for gated (prices_hidden) guests so a payment can't leak the
        # amount the cart/order totals already withhold.
        money_attributes :amount, :display_amount

        attribute :status do |payment|
          payment.state
        end

        attribute :source_type do |payment|
          case payment.source_type
          when 'Spree::CreditCard'
            'credit_card'
          when 'Spree::StoreCredit'
            'store_credit'
          when nil
            nil
          else
            'payment_source'
          end
        end

        attribute :source_id do |payment|
          payment.source&.prefixed_id
        end

        attribute :source do |payment|
          next nil if payment.source.blank?

          serializer = case payment.source_type
                       when 'Spree::CreditCard'
                         Spree.api.credit_card_serializer
                       when 'Spree::StoreCredit'
                         Spree.api.store_credit_serializer
                       else
                         Spree.api.payment_source_serializer
                       end

          serializer.new(payment.source).to_h
        end

        one :payment_method, resource: proc { Spree.api.payment_method_serializer }
      end
    end
  end
end
