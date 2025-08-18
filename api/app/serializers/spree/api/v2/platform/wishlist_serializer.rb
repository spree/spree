module Spree
  module Api
    module V2
      module Platform
        class WishlistSerializer < BaseSerializer
          include ResourceSerializerConcern

          attributes :token

          attribute :variant_included do |wishlist, params|
            wishlist.include?(params[:is_variant_included])
          end

          has_many :wished_items, serializer: Spree::Api::Dependencies.platform_wished_item_serializer.constantize
        end
      end
    end
  end
end
