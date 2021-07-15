module Spree
  module Api
    module V2
      module Platform
        class ShipmentsController < ResourceController
          before_action :find_and_update_shipment, only: [:ship, :ready, :add, :remove]

          def create
            @order = Spree::Order.find_by!(number: params.fetch(:shipment).fetch(:order_id))
            spree_authorize! :show, @order
            spree_authorize! :create, Shipment
            quantity = params[:quantity].to_i
            @shipment = @order.shipments.create(stock_location_id: params.fetch(:stock_location_id))

            @line_item = Spree::Dependencies.cart_add_item_service.constantize.call(order: @order,
                                                                                    variant: variant,
                                                                                    quantity: quantity,
                                                                                    options: { shipment: @shipment }).value

            render_serialized_payload(201) { serialize_resource(@shipment) }
          end

          def remove
            quantity = if params.key?(:quantity)
                         params[:quantity].to_i
                       else
                         @shipment.inventory_units_for(variant).sum(:quantity)
                       end

            result = Spree::Dependencies.cart_remove_item_service.constantize.call(order: @shipment.order,
                                                                                   variant: variant,
                                                                                   quantity: quantity,
                                                                                   options: { shipment: @shipment })

            if @shipment.inventory_units.any?
              @shipment.reload
            else
              @shipment.destroy!
            end

            render_shipment(result)
          end

          def ship
            @shipment.ship! unless @shipment.shipped?

            render_serialized_payload(200) { serialize_resource(@shipment) }
          end

          private

          def find_and_update_shipment
            @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).find_by!(number: params[:id])
            @shipment.update(shipment_params)
            @shipment.reload
          end

          def resource
            @resource ||= scope.find_by!(number: params[:id])
          end

          def shipment_params
            if params[:shipment] && !params[:shipment].empty?
              params.require(:shipment).permit(permitted_shipment_attributes)
            else
              {}
            end
          end

          def variant
            @variant ||= Spree::Variant.find(params[:variant_id])
          end

          def render_shipment(result)
            if result.success?
              render_serialized_payload { serialized_shipment }
            else
              render_error_payload(result.error)
            end
          end

          def serialized_shipment
            serialize_resource(@shipment)
          end

          def model_class
            Spree::Shipment
          end

          def scope_includes
            [:line_items]
          end
        end
      end
    end
  end
end
