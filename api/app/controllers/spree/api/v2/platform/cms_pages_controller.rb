module Spree
  module Api
    module V2
      module Platform
        class CmsPagesController < ResourceController
          private

          def model_class
            Spree::CmsPage
          end
        end
      end
    end
  end
end
