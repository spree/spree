module Spree
  module Api
    module V1
      class ShipmentsController < Spree::Api::BaseController

        before_action :find_and_update_shipment, only: [:ship, :ready, :add, :remove]
        before_action :load_transfer_params, only: [:transfer_to_location, :transfer_to_shipment]

        def mine
          if current_api_user.persisted?
            @shipments = Spree::Shipment
              .reverse_chronological
              .joins(:order)
              .where(spree_orders: {user_id: current_api_user.id})
              .includes(mine_includes)
              .ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          else
            render "spree/api/errors/unauthorized", status: :unauthorized
          end
        end

        def create
          @order = Spree::Order.find_by!(number: params.fetch(:shipment).fetch(:order_id))
          authorize! :read, @order
          authorize! :create, Shipment
          quantity = params[:quantity].to_i
          @shipment = @order.shipments.create(stock_location_id: params.fetch(:stock_location_id))
          @order.contents.add(variant, quantity, {shipment: @shipment})

          @shipment.save!

          respond_with(@shipment.reload, default_template: :show)
        end

        def update
          @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).friendly.find(params[:id])
          @shipment.update_attributes_and_order(shipment_params)

          respond_with(@shipment.reload, default_template: :show)
        end

        def ready
          unless @shipment.ready?
            if @shipment.can_ready?
              @shipment.ready!
            else
              render 'spree/api/v1/shipments/cannot_ready_shipment', status: 422 and return
            end
          end
          respond_with(@shipment, default_template: :show)
        end

        def ship
          unless @shipment.shipped?
            @shipment.ship!
          end
          respond_with(@shipment, default_template: :show)
        end

        def add
          quantity = params[:quantity].to_i

          @shipment.order.contents.add(variant, quantity, {shipment: @shipment})

          respond_with(@shipment, default_template: :show)
        end

        def remove
          quantity = params[:quantity].to_i

          @shipment.order.contents.remove(variant, quantity, {shipment: @shipment})
          @shipment.reload if @shipment.persisted?
          respond_with(@shipment, default_template: :show)
        end

        def transfer_to_location
          @stock_location = Spree::StockLocation.find(params[:stock_location_id])
          @original_shipment.transfer_to_location(@variant, @quantity, @stock_location)
          render json: {success: true, message: Spree.t(:shipment_transfer_success)}, status: 201
        end

        def transfer_to_shipment
          @target_shipment  = Spree::Shipment.friendly.find(params[:target_shipment_number])
          @original_shipment.transfer_to_shipment(@variant, @quantity, @target_shipment)
          render json: {success: true, message: Spree.t(:shipment_transfer_success)}, status: 201
        end

        private

        def load_transfer_params
          @original_shipment         = Spree::Shipment.friendly.find(params[:original_shipment_number])
          @variant                   = Spree::Variant.find(params[:variant_id])
          @quantity                  = params[:quantity].to_i
          authorize! :read, @original_shipment
          authorize! :create, Shipment
        end

        def find_and_update_shipment
          @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).friendly.find(params[:id])
          @shipment.update_attributes(shipment_params)
          @shipment.reload
        end

        def shipment_params
          if params[:shipment] && !params[:shipment].empty?
            params.require(:shipment).permit(permitted_shipment_attributes)
          else
            {}
          end
        end

        def variant
          @variant ||= Spree::Variant.unscoped.find(params.fetch(:variant_id))
        end

        def mine_includes
          {
            order: {
              bill_address: {
                state: {},
                country: {},
              },
              ship_address: {
                state: {},
                country: {},
              },
              adjustments: {},
              payments: {
                order: {},
                payment_method: {},
              },
            },
            inventory_units: {
              line_item: {
                product: {},
                variant: {},
              },
              variant: {
                product: {},
                default_price: {},
                option_values: {
                  option_type: {},
                },
              },
            },
          }
        end
      end
    end
  end
end
