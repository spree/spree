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

          def permitted_resource_params
            # TODO:
            # Are we allowing the Platform API to set the user for a wishlist?
            # but not expose this for the storefront API?
            params.require(model_param_name).permit(spree_permitted_attributes << :user_id)
          end
        end
      end
    end
  end
end
