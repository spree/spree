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
              product: [:variants_including_master, :variant_images, :master, { variants: [:prices] }]
            ]
          end
        end
      end
    end
  end
end
