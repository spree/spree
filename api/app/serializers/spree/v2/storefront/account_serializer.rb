module Spree
  module V2
    module Storefront
      class AccountSerializer < BaseSerializer
        set_type :user

        attributes :email

        attribute :store_credits, &:total_available_store_credit

        attribute :completed_orders do |object|
          object.orders.complete.count
        end
      end
    end
  end
end
