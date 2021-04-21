module Spree
  module Api
    module V2
      module Platform
        class OptionTypesController < ResourceController
          private

          def model_class
            Spree::OptionType
          end
        end
      end
    end
  end
end
