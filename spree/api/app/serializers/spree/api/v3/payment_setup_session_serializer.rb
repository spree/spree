module Spree
  module Api
    module V3
      class PaymentSetupSessionSerializer < BaseSerializer
        typelize status: [:string, enum: Spree::PaymentSetupSession.statuses, enum_type_name: 'PaymentSetupSessionStatus'], external_id: [:string, nullable: true], external_client_secret: [:string, nullable: true],
                 external_data: 'Record<string, unknown>',
                 payment_method_id: [:string, nullable: true], payment_source_id: [:string, nullable: true],
                 payment_source_type: [:string, nullable: true], customer_id: [:string, nullable: true]

        attributes :status, :external_id, :external_client_secret, :external_data

        prefixed_id_attributes :payment_method, :payment_source

        attribute :payment_source_type do |session|
          Spree::Base.polymorphic_api_type(session.payment_source_type)
        end

        prefixed_id_attributes :customer

        one :payment_method, resource: proc { Spree.api.payment_method_serializer }
      end
    end
  end
end
