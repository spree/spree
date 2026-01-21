module Spree
  module Api
    module V3
      module Storefront
        class CountriesController < ResourceController
          protected

          def scope
            Spree::Country.accessible_by(current_ability, :show)
          end

          def model_class
            Spree::Country
          end

          def serializer_class
            Spree.api.v3_storefront_country_serializer
          end
        end
      end
    end
  end
end
