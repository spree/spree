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
            Spree::Order.json_api_permitted_attributes + [:option_value_ids, :price, :currency]
          end
        end
      end
    end
  end
end
