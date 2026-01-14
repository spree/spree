module Spree
  module Api
    module V3
      module Storefront
        class StatesController < ResourceController
          # Public endpoint - no authentication required

          before_action :set_country, if: -> { params[:country_id].present? }

          protected

          def set_country
            @country = Spree::Country.find(params[:country_id])
          end

          def scope
            base_scope = @country ? @country.states : Spree::State
            base_scope.accessible_by(current_ability, :show)
          end

          def model_class
            Spree::State
          end

          def serializer_class
            Spree.api.v3_storefront_state_serializer
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
