module Spree
  module Api
    module V2
      module Platform
        class ShipmentsController < ResourceController
          SHIPMENT_STATES = %w[ready ship cancel resume pend]

          def update
            result = update_service.call(shipment: resource, shipment_attributes: resource_permitted_attributes)
            render_result(result)
          end

          SHIPMENT_STATES.each do |state|
            define_method state do
              result = change_state_service.call(shipment: resource, state: state)
              render_result(result)
            end
          end

          private

          def model_class
            Spree::Shipment
          end

          def resource
            @resource ||= scope.find_by(number: params[:id]) || scope.find(params[:id])
          end

          def spree_permitted_attributes
            Spree::Shipment.json_api_permitted_attributes + [
              :selected_shipping_rate_id
            ]
          end

          def update_service
            Spree::Api::Dependencies.platform_shipment_update_service.constantize
          end

          def change_state_service
            Spree::Api::Dependencies.platform_shipment_change_state_service.constantize
          end
        end
      end
    end
  end
end
