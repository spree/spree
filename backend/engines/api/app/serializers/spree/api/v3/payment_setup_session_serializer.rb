module Spree
  module Api
    module V3
      class PaymentSetupSessionSerializer < BaseSerializer
        typelize status: :string, external_id: [:string, nullable: true], external_client_secret: [:string, nullable: true],
                 external_data: 'Record<string, unknown>',
                 payment_method_id: [:string, nullable: true], payment_source_id: [:string, nullable: true],
                 payment_source_type: [:string, nullable: true], customer_id: [:string, nullable: true]

        attributes :status, :external_id, :external_client_secret, :external_data,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :payment_method_id do |session|
          session.payment_method&.prefixed_id
        end

        attribute :payment_source_id do |session|
          session.payment_source&.prefixed_id
        end

        attribute :payment_source_type do |session|
          session.payment_source_type
        end

        attribute :customer_id do |session|
          session.customer&.prefixed_id
        end

        one :payment_method, resource: Spree.api.payment_method_serializer
      end
    end
  end
end
