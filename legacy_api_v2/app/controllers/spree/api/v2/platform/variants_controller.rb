module Spree
  module Api
    module V2
      module Platform
        class VariantsController < ResourceController
          private

          def model_class
            Spree::Variant
          end

          def spree_permitted_attributes
            super + [:option_value_ids, :price, :currency]
          end

          def resource_serializer
            Spree.api.platform_variant_serializer
          end
        end
      end
    end
  end
end
