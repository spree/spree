module Spree
  module Api
    module V3
      module Storefront
        class ShippingMethodsController < BaseController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!

          # GET /api/v3/storefront/orders/:order_id/shipping_methods
          def index
            @shipping_methods = available_shipping_methods

            render json: {
              data: serialize_collection(@shipping_methods)
            }
          end

          protected

          def available_shipping_methods
            @order.available_shipping_methods
          end

          def serialize_collection(collection)
            collection.map { |item| serializer_class.new(item, params: serializer_params).to_h }
          end

          def serializer_class
            Spree.api.v3_storefront_shipping_method_serializer
          end

          def serializer_params
            {
              currency: current_currency,
              store: current_store,
              locale: current_locale,
              includes: include_tree
            }
          end
        end
      end
    end
  end
end
