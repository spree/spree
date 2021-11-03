module Spree
  module Api
    module V2
      module Platform
        class MenuItemsController < ResourceController
          def reposition
            spree_authorize! :update, resource if spree_current_user.present?

            @new_parent = scope.find(permitted_resource_params[:new_parent_id])
            new_index = permitted_resource_params[:new_position_idx].to_i

            if resource.move_to_child_with_index(@new_parent, new_index)
              render_serialized_payload { serialize_resource(resource) }
            else
              render_error_payload(resource.errors)
            end
          end

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
