module Spree
  module Api
    module V3
      module Storefront
        class CountriesController < ResourceController
          # Public endpoint - no authentication required

          protected

          def scope
            Spree::Country.accessible_by(current_ability, :show)
          end

          def model_class
            Spree::Country
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_country_serializer.constantize
          end

          # Not needed for index/show
          def permitted_params
            {}
          end
        end
      end
    end
  end
end
