module Spree
  module Api
    module V2
      module Platform
        class CmsSectionsController < ResourceController
          before_action -> { doorkeeper_authorize! :write, :admin }, only: WRITE_ACTIONS << :reposition

          def reposition
            spree_authorize! :update, @moved_section if spree_current_user.present?

            @moved_section = scope.find(params[:section_id])
            new_index = params[:new_position_idx].to_i + 1

            if @moved_section && new_index
              @moved_section.insert_at(new_index)
            else
              head :bad_request
            end

            if @moved_section.save
              head :no_content
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
