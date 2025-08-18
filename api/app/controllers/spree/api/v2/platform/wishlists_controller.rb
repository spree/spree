module Spree
  module Api
    module V2
      module Platform
        class WishlistsController < ResourceController
          private

          def model_class
            Spree::Wishlist
          end

          def scope_includes
            [:wished_items]
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_wishlist_serializer.constantize
          end
        end
      end
    end
  end
end
