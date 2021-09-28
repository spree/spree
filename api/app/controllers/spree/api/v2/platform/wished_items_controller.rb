module Spree
  module Api
    module V2
      module Platform
        class WishedItemsController < ResourceController
          private

          def scope_includes
            [:variant]
          end

          def model_class
            Spree::WishedItem
          end

          def permitted_resource_params
            params.require(model_param_name).permit(spree_permitted_attributes << :wishlist_id)
          end
        end
      end
    end
  end
end
