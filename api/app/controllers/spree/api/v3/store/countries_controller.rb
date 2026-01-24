module Spree
  module Api
    module V3
      module Store
        class CountriesController < Store::ResourceController
          protected

          def scope
            Spree::Country.accessible_by(current_ability, :show)
          end

          def model_class
            Spree::Country
          end

          def serializer_class
            Spree.api.country_serializer
          end
        end
      end
    end
  end
end
