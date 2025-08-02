module Spree
  module Api
    module V2
      module Platform
        class CountriesController < ResourceController
          private

          def model_class
            Spree::Country
          end

          def scope_includes
            [:states, :zones]
          end

          def resource_serializer
            Spree::Api::Dependencies.platform_country_serializer.constantize
          end
        end
      end
    end
  end
end
