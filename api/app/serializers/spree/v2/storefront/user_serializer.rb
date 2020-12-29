module Spree
  module V2
    module Storefront
      class UserSerializer < BaseSerializer
        set_type :user

        attributes :email

        attribute :store_credits, &:total_available_store_credit

        attribute :completed_orders do |object|
          object.orders.complete.count
        end

        has_one :default_billing_address,
          id_method_name: :bill_address_id,
          object_method_name: :bill_address,
          record_type: :address,
          serializer: :address

        has_one :default_shipping_address,
          id_method_name: :ship_address_id,
          object_method_name: :ship_address,
          record_type: :address,
          serializer: :address
      end
    end
  end
end
