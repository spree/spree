module Spree
  module Api
    module V2
      module Storefront
        class CheckoutController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::Storefront::OrderConcern
          before_action :ensure_order

          def next
            spree_authorize! :update, spree_current_order, order_token

            result = next_service.constantize.call(order: spree_current_order)

            render_order(result)
          end

          def advance
            spree_authorize! :update, spree_current_order, order_token

            result = advance_service.constantize.call(order: spree_current_order)

            render_order(result)
          end

          def complete
            spree_authorize! :update, spree_current_order, order_token

            result = complete_service.constantize.call(order: spree_current_order)

            render_order(result)
          end

          def update
            spree_authorize! :update, spree_current_order, order_token

            result = update_service.constantize.call(
              order: spree_current_order,
              params: params,
              # defined in https://github.com/spree/spree/blob/master/core/lib/spree/core/controller_helpers/strong_parameters.rb#L19
              permitted_attributes: permitted_checkout_attributes,
              request_env: request.headers.env
            )

            render_order(result)
          end

          def add_store_credit
            spree_authorize! :update, spree_current_order, order_token

            result = add_store_credit_service.constantize.call(
              order: spree_current_order,
              amount: params[:amount].try(:to_f)
            )

            render_order(result)
          end

          def remove_store_credit
            spree_authorize! :update, spree_current_order, order_token

            result = remove_store_credit_service.constantize.call(order: spree_current_order)
            render_order(result)
          end

          def shipping_rates
            result = get_shipping_rates_service.constantize.call(order: spree_current_order)

            render_serialized_payload { serialize_shipping_rates(result.value) }
          end

          def payment_methods
            render_serialized_payload { serialize_payment_methods(spree_current_order.available_payment_methods) }
          end

          private

          def resource_serializer
            Spree::Api::Dependencies.storefront_cart_serializer
          end

          def next_service
            Spree::Api::Dependencies.storefront_checkout_next_service
          end

          def advance_service
            Spree::Api::Dependencies.storefront_checkout_advance_service
          end

          def add_store_credit_service
            Spree::Api::Dependencies.storefront_checkout_add_store_credit_service
          end

          def remove_store_credit_service
            Spree::Api::Dependencies.storefront_checkout_remove_store_credit_service
          end

          def complete_service
            Spree::Api::Dependencies.storefront_checkout_complete_service
          end

          def update_service
            Spree::Api::Dependencies.storefront_checkout_update_service
          end

          def payment_methods_serializer
            Spree::Api::Dependencies.storefront_payment_method_serializer
          end

          def get_shipping_rates_service
            Spree::Api::Dependencies.storefront_checkout_get_shipping_rates_service
          end

          def shipping_rates_serializer
            Spree::Api::Dependencies.storefront_shipment_serializer
          end

          def serialize_payment_methods(payment_methods)
            payment_methods_serializer.constantize.new(payment_methods).serializable_hash
          end

          def serialize_shipping_rates(shipments)
            shipping_rates_serializer.constantize.new(
              shipments,
              include: [:shipping_rates],
              params: { show_rates: true }
            ).serializable_hash
          end
        end
      end
    end
  end
end
