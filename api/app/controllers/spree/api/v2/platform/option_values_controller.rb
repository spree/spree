module Spree
  module Api
    module V2
      module Platform
        class OptionValuesController < ResourceController
          private

          def model_class
            Spree::OptionValue
          end

          def scope_includes
            [:option_type]
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_option_value_serializer.constantize
          end
        end
      end
    end
  end
end
