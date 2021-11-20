module Spree
  module Api
    module V2
      module Platform
        module NestedSetRepositionConcern
          def reposition
            spree_authorize! :update, resource if spree_current_user.present?

            @new_parent = scope.find(permitted_resource_params[:new_parent_id])
            new_index = permitted_resource_params[:new_position_idx].to_i

            if resource.move_to_child_with_index(@new_parent, new_index)
              successful_reposition_actions
            else
              render_error_payload(resource.errors)
            end
          end

          private

          def successful_reposition_actions
            render_serialized_payload { serialize_resource(resource) }
          end
        end
      end
    end
  end
end
