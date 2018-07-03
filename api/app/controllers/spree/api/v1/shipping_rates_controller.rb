module Spree
  module Api
    module V1
      class ShippingRatesController < Spree::Api::BaseController
        before_action :find_order

        # This action provides predicted shipping rates for order based on provided
        # country and state
        def index
          order = @order.dup
          order.line_items = @order.line_items
          country_id = params[:country_id] || Spree::Country.default.id
          order.ship_address = Spree::Address.new(country_id: country_id, state_id: params[:state_id])
          packages = Spree::Stock::Coordinator.new(order).packages
          estimator = Spree::Stock::Estimator.new(order)
          @shipping_rates = if @order.line_items.any? && packages.any?
                              estimator.shipping_rates(packages.first)
                            else
                              []
                            end
        end

        # This action is used to change selected shipping rate
        def select
          authorize! :update, @order, order_token
          shipping_rates = @order.update_shipments_rates(params[:shipping_method_id])
          render json: shipping_rates
        end

        private

        def find_order
          @order = Spree::Order.find_by!(number: order_id)
        end
      end
    end
  end
end
