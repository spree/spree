module Spree
  module Api
    module V3
      class PaymentSerializer < BaseSerializer
        typelize state: :string, payment_method_id: :string, response_code: 'string | null',
                 number: :string, amount: :string, display_amount: :string,
                 source_type: "'credit_card' | 'store_credit' | 'payment_source' | null",
                 source: 'StoreCreditCard | StoreStoreCredit | StorePaymentSource | null'

        attribute :payment_method_id do |payment|
          payment.payment_method&.prefixed_id
        end

        attributes :state, :response_code, :number, :amount, :display_amount,
                   created_at: :iso8601, updated_at: :iso8601

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

        one :payment_method, resource: Spree.api.payment_method_serializer
      end
    end
  end
end
