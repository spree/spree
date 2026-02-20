module Spree
  module Api
    module V3
      # Store API Customer Serializer
      # Customer-facing user data
      class CustomerSerializer < BaseSerializer
        typelize email: :string, first_name: [:string, nullable: true], last_name: [:string, nullable: true],
                 default_billing_address: { nullable: true }, default_shipping_address: { nullable: true }

        attributes :email, :first_name, :last_name,
                   created_at: :iso8601, updated_at: :iso8601

        many :addresses, resource: Spree.api.address_serializer
        one :bill_address, key: :default_billing_address, resource: Spree.api.address_serializer
        one :ship_address, key: :default_shipping_address, resource: Spree.api.address_serializer
      end
    end
  end
end
