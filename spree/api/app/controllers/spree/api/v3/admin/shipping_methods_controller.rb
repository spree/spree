module Spree
  module Api
    module V3
      module Admin
        class ShippingMethodsController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::ShippingMethod
          end

          def serializer_class
            Spree.api.admin_shipping_method_serializer
          end

          def permitted_params
            params.permit(:name, :display_on, :tax_category_id,
                         :estimated_transit_business_days_min,
                         :estimated_transit_business_days_max,
                         shipping_category_ids: [], zone_ids: [])
          end
        end
      end
    end
  end
end
