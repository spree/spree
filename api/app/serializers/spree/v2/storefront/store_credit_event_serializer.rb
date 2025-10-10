module Spree
  module V2
    module Storefront
      class StoreCreditEventSerializer < BaseSerializer
        set_type :store_credit_event

        attributes :action, :amount, :user_total_amount, :created_at

        attribute :order_number do |object|
          object.order&.number
        end
      end
    end
  end
end
