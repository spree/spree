module Spree
  module Api
    module V2
      module Platform
        class ShipmentsController < ResourceController
          include NumberResource

          before_action :load_variant, only: %i[remove_item transfer_to_location transfer_to_shipment]
          before_action :load_stock_location, only: %i[transfer_to_location]

          SHIPMENT_STATES = %w[ready ship cancel resume pend]

          def create
            # FIXME: support saving metadata
            result = create_service.call(
              store: current_store,
              shipment_attributes: params.require(:shipment).permit(
                :order_id, :stock_location_id, :variant_id, :quantity
              )
            )
            render_result(result, 201)
          end

          def update
            result = update_service.call(shipment: resource, shipment_attributes: permitted_resource_params)
            render_result(result)
          end

          SHIPMENT_STATES.each do |state|
            define_method state do
              result = change_state_service.call(shipment: resource, state: state)
              render_result(result)
            end
          end

          def add_item
            result = add_item_service.call(
              shipment: resource,
              variant_id: params.dig(:shipment, :variant_id),
              quantity: params.dig(:shipment, :quantity)
            )
            render_result(result)
          end

          # removes an item (variant) from shipment
          # quantity can be passed
          # if there is no quantity left for this item for this shipent, shipment itself will be removed
          # TODO: move this code
          # def remove_item
          #   quantity = params.dig(:shipment, :quantity)&.to_i || resource.inventory_units_for(variant).sum(:quantity)

          #   result = Spree::Dependencies.cart_remove_item_service.constantize.call(order: resource.order,
          #                                                                          variant: @variant,
          #                                                                          quantity: quantity,
          #                                                                          options: { shipment: resource })

          #   if result.success?
          #     if resource.inventory_units.any?
          #       render_serialized_payload { serialize_resource(resource.reload) }
          #     elsif resource.detroy!
          #       head 204
          #     else
          #       render_error_payload(resource)
          #     end
          #   else
          #     render_error_payload(result.error)
          #   end
          # end

          # def transfer_to_location
          #   quantity = params.dig(:shipment, :quantity)&.to_i || 1

          #   unless quantity > 0
          #     unprocessable_entity("#{Spree.t(:shipment_transfer_errors_occurred, scope: 'api')} \n #{Spree.t(:negative_quantity, scope: 'api')}")
          #     return
          #   end

          #   transfer = resource.transfer_to_location(@variant, quantity, stock_location)
          #   if transfer.valid?
          #     transfer.run!
          #     render json: { message: Spree.t(:shipment_transfer_success) }, status: 201
          #   else
          #     render json: { message: transfer.errors.full_messages.to_sentence }, status: 422
          #   end
          # end

          # def transfer_to_shipment
          #   @target_shipment = Spree::Shipment.find_by!(number: params[:target_shipment_number])

          #   error =
          #     if @quantity < 0 && @target_shipment == @original_shipment
          #       "#{Spree.t(:negative_quantity, scope: 'api')}, \n#{Spree.t('wrong_shipment_target', scope: 'api')}"
          #     elsif @target_shipment == @original_shipment
          #       Spree.t(:wrong_shipment_target, scope: 'api')
          #     elsif @quantity < 0
          #       Spree.t(:negative_quantity, scope: 'api')
          #     end

          #   if error
          #     unprocessable_entity("#{Spree.t(:shipment_transfer_errors_occurred, scope: 'api')} \n#{error}")
          #   else
          #     transfer = @original_shipment.transfer_to_shipment(@variant, @quantity, @target_shipment)
          #     if transfer.valid?
          #       transfer.run!
          #       render json: { message: Spree.t(:shipment_transfer_success) }, status: 201
          #     else
          #       render json: { message: transfer.errors.full_messages }, status: 422
          #     end
          #   end
          # end

          private

          def model_class
            Spree::Shipment
          end

          def load_variant
            @variant = current_store.variants.find_by(id: params.dig(:shipment, :variant_id))
          end

          def load_stock_location
            @stock_location = Spree::StockLocation.find(params.dig(:shipment, :stock_location_id))
          end

          def spree_permitted_attributes
            Spree::Shipment.json_api_permitted_attributes + [
              :selected_shipping_rate_id
            ]
          end

          def create_service
            Spree::Api::Dependencies.platform_shipment_create_service.constantize
          end

          def update_service
            Spree::Api::Dependencies.platform_shipment_update_service.constantize
          end

          def change_state_service
            Spree::Api::Dependencies.platform_shipment_change_state_service.constantize
          end

          def add_item_service
            Spree::Api::Dependencies.platform_shipment_add_item_service.constantize
          end
        end
      end
    end
  end
end
