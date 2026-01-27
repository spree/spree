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
              # If successful reposition call the custom method for handling success.
              successful_reposition_actions
            elsif resource.errors.any?
              # If there are errors output them to the response
              render_error_payload(resource.errors.full_messages.to_sentence)
            else
              # If the user drops the re-positioned item in the same location it came from
              # we just render the serialized payload, nothing has changed, we don't need to
              # render any errors, or fire any custom success methods.
              render_serialized_payload { serialize_resource(resource) }
            end
          end

          private

          def successful_reposition_actions
            # Call a separate method for a successful reposition so this can be easily overridden
            # if a more complex set of events need to occur after a successful reposition.
            render_serialized_payload { serialize_resource(resource) }
          end
        end
      end
    end
  end
end
