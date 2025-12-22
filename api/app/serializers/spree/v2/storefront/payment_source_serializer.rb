module Spree
  module V2
    module Storefront
      class PaymentSourceSerializer < BaseSerializer
        include Spree::Api::V2::PublicMetafieldsConcern

        belongs_to :payment_method, serializer: Spree.api.storefront_payment_method_serializer
        belongs_to :user, serializer: Spree.api.storefront_user_serializer
      end
    end
  end
end
