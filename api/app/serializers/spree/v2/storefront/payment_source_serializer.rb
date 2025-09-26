module Spree
  module V2
    module Storefront
      class PaymentSourceSerializer < BaseSerializer
        include Spree::Api::V2::PublicMetafieldsConcern

        belongs_to :payment_method, serializer: Spree::Api::Dependencies.storefront_payment_method_serializer.constantize
        belongs_to :user, serializer: Spree::Api::Dependencies.storefront_user_serializer.constantize
      end
    end
  end
end
