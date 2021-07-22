module Spree
  module Api
    module V2
      module Platform
        class CmsPagesController < ResourceController
          before_action -> { doorkeeper_authorize! :write, :admin }, only: WRITE_ACTIONS << :toggle_visibility

          private

          def model_class
            Spree::CmsPage
          end
        end
      end
    end
  end
end
