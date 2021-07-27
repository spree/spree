module Spree
  module Api
    module V2
      module Platform
        class VariantsController < ResourceController
          def model_class
            Spree::Variant
          end
        end
      end
    end
  end
end
