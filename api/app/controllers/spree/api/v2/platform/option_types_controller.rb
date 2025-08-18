module Spree
  module Api
    module V2
      module Platform
        class OptionTypesController < ResourceController
          private

          def model_class
            Spree::OptionType
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_option_type_serializer.constantize
          end
        end
      end
    end
  end
end
