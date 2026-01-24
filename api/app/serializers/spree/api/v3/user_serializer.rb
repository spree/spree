module Spree
  module Api
    module V3
      # Store API User Serializer
      # Customer-facing user data
      class UserSerializer < BaseSerializer
        typelize email: :string, first_name: 'string | null', last_name: 'string | null'

        attributes :email, :first_name, :last_name,
                   created_at: :iso8601, updated_at: :iso8601

        many :addresses, resource: Spree.api.address_serializer
        one :bill_address, key: :default_billing_address, resource: Spree.api.address_serializer
        one :ship_address, key: :default_shipping_address, resource: Spree.api.address_serializer
      end
    end
  end
end
