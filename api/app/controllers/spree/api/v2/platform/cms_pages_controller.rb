module Spree
  module Api
    module V2
      module Platform
        class CmsPagesController < ResourceController
          before_action -> { doorkeeper_authorize! :write, :admin }, only: WRITE_ACTIONS << :toggle_visibility

          def toggle_visibility
            spree_authorize! :update, @toggle_page if spree_current_user.present?

            @toggle_page = scope.find(params[:id])

            if @toggle_page
              @toggle_page.toggle!(:visible)
            else
              head :bad_request
            end

            if @toggle_page.save
              head :no_content
            end
          end

          private

          def model_class
            Spree::CmsPage
          end
        end
      end
    end
  end
end
