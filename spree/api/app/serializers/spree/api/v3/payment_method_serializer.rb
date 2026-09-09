module Spree
  module Api
    module V3
      class PaymentMethodSerializer < BaseSerializer
        typelize name: :string, description: [:string, nullable: true], type: [:string, comment: 'Payment method type. Built-in: check, store_credit, custom_payment_source_method, bogus (test only); payment provider gems register their own, for example stripe.'],
                 session_required: :boolean, source_required: :boolean

        attributes :name, :description

        attribute :type do |payment_method|
          payment_method.class.api_type
        end

        attribute :session_required do |payment_method|
          payment_method.session_required?
        end

        attribute :source_required do |payment_method|
          payment_method.source_required?
        end
      end
    end
  end
end
