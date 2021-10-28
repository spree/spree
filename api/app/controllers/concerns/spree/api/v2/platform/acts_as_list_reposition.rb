module Spree
  module Api
    module V2
      module Platform
        module ActsAsListReposition
          def reposition
            spree_authorize! :update, @moved_resource if spree_current_user.present?

            unless params[:new_position_idx].present?
              render json: { error: I18n.t('spree.api.v2.generic_errors.could_not_reposition') }, status: 422
              return
            end

            @moved_resource = scope.find(params[:id])
            new_index = params[:new_position_idx].to_i + 1

            if @moved_resource && new_index
              @moved_resource.set_list_position(new_index)
            else
              head :bad_request
            end

            if @moved_resource.save
              render_serialized_payload { serialize_resource(resource) }
            end
          end
        end
      end
    end
  end
end
