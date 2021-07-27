module Spree
  module Api
    module V2
      module Platform
        class ShipmentsController < ResourceController
          ORDER_WRITE_ACTIONS = %i[create update destroy add remove]

          before_action -> { doorkeeper_authorize! :write, :admin }, only: ORDER_WRITE_ACTIONS
          before_action :find_and_update_shipment, only: [:ship, :ready, :add, :remove]
          before_action :load_transfer_params, only: [:transfer_to_location, :transfer_to_shipment]

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

          def update
            @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).find_by!(number: params[:id])
            @shipment.update_attributes_and_order(shipment_params)

            render_serialized_payload(201) { serialize_resource(@shipment) }
          end

          def ready
            unless @shipment.ready?
              if @shipment.can_ready?
                @shipment.ready!
              else
                return render_error_payload(Spree.t('v2.shipment.cannot_ready_shipment', scope: 'api'))
              end
            end
            render_serialized_payload(200) { serialize_resource(@shipment) }
          end

          def ship
            @shipment.ship! unless @shipment.shipped?

            render_serialized_payload(200) { serialize_resource(@shipment) }
          end

          def add
            spree_authorize! :update, @shipment

            quantity = params[:quantity].to_i

            result = Spree::Dependencies.cart_add_item_service.constantize.call(order: @shipment.order,
                                                                                variant: variant,
                                                                                quantity: quantity,
                                                                                options: { shipment: @shipment })

            render_shipment(result)
          end

          def remove
            spree_authorize! :update, @shipment

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

          def transfer_to_location
            @stock_location = Spree::StockLocation.find(params[:stock_location_id])

            unless @quantity > 0
              unprocessable_entity("#{Spree.t(:shipment_transfer_errors_occurred, scope: 'api')} \n #{Spree.t(:negative_quantity, scope: 'api')}")
              return
            end

            transfer = @original_shipment.transfer_to_location(@variant, @quantity, @stock_location)
            if transfer.valid?
              transfer.run!
              render json: { message: Spree.t(:shipment_transfer_success) }, status: 201
            else
              render json: { message: transfer.errors.full_messages.to_sentence }, status: 422
            end
          end

          def transfer_to_shipment
            @target_shipment = Spree::Shipment.find_by!(number: params[:target_shipment_number])

            error =
              if @quantity < 0 && @target_shipment == @original_shipment
                "#{Spree.t(:negative_quantity, scope: 'api')}, \n#{Spree.t('wrong_shipment_target', scope: 'api')}"
              elsif @target_shipment == @original_shipment
                Spree.t(:wrong_shipment_target, scope: 'api')
              elsif @quantity < 0
                Spree.t(:negative_quantity, scope: 'api')
              end

            if error
              unprocessable_entity("#{Spree.t(:shipment_transfer_errors_occurred, scope: 'api')} \n#{error}")
            else
              transfer = @original_shipment.transfer_to_shipment(@variant, @quantity, @target_shipment)
              if transfer.valid?
                transfer.run!
                render json: { message: Spree.t(:shipment_transfer_success) }, status: 201
              else
                render json: { message: transfer.errors.full_messages }, status: 422
              end
            end
          end

          private

          def load_transfer_params
            @original_shipment         = Spree::Shipment.find_by!(number: params[:original_shipment_number])
            @variant                   = Spree::Variant.find(params[:variant_id])
            @quantity                  = params[:quantity].to_i

            spree_authorize! :show, @original_shipment
            spree_authorize! :create, Shipment
          end

          def find_and_update_shipment
            @shipment = Spree::Shipment.find_by!(number: params[:id])
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
            [:shipping_methods]
          end
        end
      end
    end
  end
end
