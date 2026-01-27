module Spree
  module Api
    module V2
      module Platform
        class ClassificationsController < ResourceController
          private

          def model_class
            Spree::Classification
          end

          def scope_includes
            [
              taxon: [],
              product: [:variants_including_master, :master, { variants: [:prices] }]
            ]
          end

          def resource_serializer
            Spree.api.platform_classification_serializer
          end
        end
      end
    end
  end
end
