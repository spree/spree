module Spree
  module Api
    module V2
      module Platform
        class MenuItemsController < ResourceController
          include ::Spree::Api::V2::Platform::NestedSetRepositionConcern

          private

          def model_class
            Spree::MenuItem
          end

          def spree_permitted_attributes
            super + [:new_parent_id, :new_position_idx]
          end
        end
      end
    end
  end
end
