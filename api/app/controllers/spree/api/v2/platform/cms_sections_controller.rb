module Spree
  module Api
    module V2
      module Platform
        class CmsSectionsController < ResourceController
          include ::Spree::Api::V2::Platform::ActsAsListReposition

          private

          def model_class
            Spree::CmsSection
          end
        end
      end
    end
  end
end
