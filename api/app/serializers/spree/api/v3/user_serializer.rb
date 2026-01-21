module Spree
  module Api
    module V3
      class UserSerializer < BaseSerializer
        attributes :id, :email, :first_name, :last_name

        many :addresses, resource: Spree.api.v3_storefront_address_serializer
        one :default_billing_address, resource: Spree.api.v3_storefront_address_serializer
        one :default_shipping_address, resource: Spree.api.v3_storefront_address_serializer
      end
    end
  end
end
