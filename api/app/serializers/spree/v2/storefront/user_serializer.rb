module Spree
  module V2
    module Storefront
      class UserSerializer < BaseSerializer
        set_type :user

        attributes :email, :first_name, :selected_locale, :last_name, :public_metadata

        attribute :tags, &:tag_list

        attribute :store_credits do |user|
          user.total_available_store_credit
        end

        attribute :completed_orders do |object|
          object.orders.complete.count
        end

        has_one :default_billing_address,
                id_method_name: :bill_address_id,
                object_method_name: :bill_address,
                record_type: :address,
                serializer: Spree::Api::Dependencies.storefront_address_serializer.constantize

        has_one :default_shipping_address,
                id_method_name: :ship_address_id,
                object_method_name: :ship_address,
                record_type: :address,
                serializer: Spree::Api::Dependencies.storefront_address_serializer.constantize
      end
    end
  end
end
