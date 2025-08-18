module Spree
  module Api
    module V2
      module Platform
        class GiftCardSerializer < BaseSerializer
          include ResourceSerializerConcern

          set_type :gift_card

          belongs_to :user, serializer: Spree::Api::Dependencies.platform_user_serializer.constantize

          has_many :orders, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
        end
      end
    end
  end
end
