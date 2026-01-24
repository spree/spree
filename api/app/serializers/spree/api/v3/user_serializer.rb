module Spree
  module Api
    module V3
      # Store API User Serializer
      # Customer-facing user data
      class UserSerializer < BaseSerializer
        # Note: Using Spree.user_class dynamically, typelize_from not applicable here

        attributes :id, :email, :first_name, :last_name,
                   created_at: :iso8601, updated_at: :iso8601

        many :addresses, resource: Spree.api.address_serializer
        one :bill_address, key: :default_billing_address, resource: Spree.api.address_serializer
        one :ship_address, key: :default_shipping_address, resource: Spree.api.address_serializer
      end
    end
  end
end
