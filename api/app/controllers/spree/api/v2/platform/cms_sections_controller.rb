module Spree
  module Api
    module V2
      module Platform
        class CmsSectionsController < ResourceController
          def reposition
            spree_authorize! :update, @moved_section if spree_current_user.present?

            unless params[:new_position_idx].present?
              render json: { error: I18n.t('spree.api.v2.cms_sections.pass_position_index') }, status: 422
              return
            end

            @moved_section = scope.find(params[:id])
            new_index = params[:new_position_idx].to_i + 1

            if @moved_section && new_index
              @moved_section.set_list_position(new_index)
            else
              head :bad_request
            end

            if @moved_section.save
              render_serialized_payload { serialize_resource(resource) }
            end
          end

          private

          def model_class
            Spree::CmsSection
          end
        end
      end
    end
  end
end
