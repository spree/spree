module Spree
  module Api
    module V3
      module Admin
        class StockLocationsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::StockLocation
          end

          def serializer_class
            Spree.api.admin_stock_location_serializer
          end

          def scope
            super.order_default
          end

          def permitted_params
            params.permit(
              :name, :admin_name, :active, :default,
              :kind, :propagate_all_variants, :backorderable_default,
              :address1, :address2, :city, :zipcode, :phone, :company,
              :country_iso, :state_abbr, :state_name,
              :pickup_enabled, :pickup_stock_policy,
              :pickup_ready_in_minutes, :pickup_instructions
            )
          end
        end
      end
    end
  end
end
