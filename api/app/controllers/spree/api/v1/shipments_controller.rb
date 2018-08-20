module Spree
  module Api
    module V1
      class ShipmentsController < Spree::Api::BaseController
        before_action :find_and_update_shipment, only: [:ship, :ready, :add, :remove]
        before_action :load_transfer_params, only: [:transfer_to_location, :transfer_to_shipment]

        def mine
          if current_api_user.persisted?
            @shipments = Spree::Shipment.
                         reverse_chronological.
                         joins(:order).
                         where(spree_orders: { user_id: current_api_user.id }).
                         includes(mine_includes).
                         ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          else
            render 'spree/api/errors/unauthorized', status: :unauthorized
          end
        end

        def create
          @order = Spree::Order.find_by!(number: params.fetch(:shipment).fetch(:order_id))
          authorize! :read, @order
          authorize! :create, Shipment
          quantity = params[:quantity].to_i
          @shipment = @order.shipments.create(stock_location_id: params.fetch(:stock_location_id))
          @order.contents.add(variant, quantity, shipment: @shipment)

          respond_with(@shipment.reload, default_template: :show)
        end

        def update
          @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).find_by!(number: params[:id])
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
          @shipment.ship! unless @shipment.shipped?
          respond_with(@shipment, default_template: :show)
        end

        def add
          quantity = params[:quantity].to_i

          @shipment.order.contents.add(variant, quantity, shipment: @shipment)
          respond_with(@shipment, default_template: :show)
        end

        def remove
          quantity = if params.key?(:quantity)
                       params[:quantity].to_i
                     else
                       @shipment.inventory_units_for(variant).sum(:quantity)
                     end
          @shipment.order.contents.remove(variant, quantity, shipment: @shipment)

          if @shipment.inventory_units.any?
            @shipment.reload
          else
            @shipment.destroy!
          end

          respond_with(@shipment, default_template: :show)
        end

        def transfer_to_location
          @stock_location = Spree::StockLocation.find(params[:stock_location_id])

          unless @quantity > 0
            unprocessable_entity("#{Spree.t(:shipment_transfer_errors_occured, scope: 'api')} \n #{Spree.t(:negative_quantity, scope: 'api')}")
            return
          end

          @original_shipment.transfer_to_location(@variant, @quantity, @stock_location, @options)
          render json: { success: true, message: Spree.t(:shipment_transfer_success) }, status: 201
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
            unprocessable_entity("#{Spree.t(:shipment_transfer_errors_occured, scope: 'api')} \n#{error}")
          else
            @original_shipment.transfer_to_shipment(@variant, @quantity, @target_shipment, @options)
            render json: { success: true, message: Spree.t(:shipment_transfer_success) }, status: 201
          end
        end

        private

        def load_transfer_params
          @original_shipment         = Spree::Shipment.find_by!(number: params[:original_shipment_number])
          @variant                   = Spree::Variant.find(params[:variant_id])
          @quantity                  = params[:quantity].to_i
          @options                   = params[:options] || {}
          authorize! :read, @original_shipment
          authorize! :create, Shipment
        end

        def find_and_update_shipment
          @shipment = Spree::Shipment.accessible_by(current_ability, :update).readonly(false).find_by!(number: params[:id])
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
                country: {}
              },
              ship_address: {
                state: {},
                country: {}
              },
              adjustments: {},
              payments: {
                order: {},
                payment_method: {}
              }
            },
            inventory_units: {
              line_item: {
                product: {},
                variant: {}
              },
              variant: {
                product: {},
                default_price: {},
                option_values: {
                  option_type: {}
                }
              }
            }
          }
        end
      end
    end
  end
end
