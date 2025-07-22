module Spree
  module Api
    module V2
      module Storefront
        class CheckoutController < ::Spree::Api::V2::BaseController
          include Spree::Api::V2::Storefront::OrderConcern
          before_action :ensure_order

          def next
            spree_authorize! :update, spree_current_order, order_token

            result = next_service.call(order: spree_current_order)

            render_order(result)
          end

          def advance
            spree_authorize! :update, spree_current_order, order_token

            check_if_quick_checkout

            result = advance_service.call(order: spree_current_order, state: params[:state], shipping_method_id: params[:shipping_method_id])

            render_order(result)
          end

          def complete
            spree_authorize! :update, spree_current_order, order_token

            result = complete_service.call(order: spree_current_order)

            render_order(result)
          end

          def update
            spree_authorize! :update, spree_current_order, order_token

            result = update_service.call(
              order: spree_current_order,
              params: params,
              # defined in https://github.com/spree/spree/blob/main/core/lib/spree/core/controller_helpers/strong_parameters.rb#L19
              permitted_attributes: permitted_checkout_attributes,
              request_env: request.headers.env
            )

            render_order(result)
          end

          def create_payment
            result = create_payment_service.call(order: spree_current_order, params: params)

            if result.success?
              render_serialized_payload(201) { serialize_resource(spree_current_order.reload) }
            else
              render_error_payload(result.error)
            end
          end

          def select_shipping_method
            result = select_shipping_method_service.call(order: spree_current_order, params: params)

            render_order(result)
          end

          def add_store_credit
            spree_authorize! :update, spree_current_order, order_token

            result = add_store_credit_service.call(
              order: spree_current_order,
              amount: params[:amount].try(:to_f)
            )

            render_order(result)
          end

          def remove_store_credit
            spree_authorize! :update, spree_current_order, order_token

            result = remove_store_credit_service.call(order: spree_current_order)
            render_order(result)
          end

          def shipping_rates
            result = shipping_rates_service.call(order: spree_current_order)

            if result.success?
              render_serialized_payload { serialize_shipping_rates(result.value) }
            else
              render_error_payload(result.error)
            end
          end

          def payment_methods
            render_serialized_payload { serialize_payment_methods(spree_current_order.collect_frontend_payment_methods) }
          end

          def validate_order_for_payment
            messages = []

            if spree_current_order.present?
              validated_order, messages = Spree::Cart::RemoveOutOfStockItems.call(order: spree_current_order).value
              messages << Spree.t(:cart_state_changed) if !validated_order.payment? && params[:skip_state].blank?
            end

            if messages.any?
              render_serialized_payload(422) do
                serialized_current_order.deep_merge({ meta: { messages: messages } })
              end
            else
              render_serialized_payload { serialized_current_order }
            end
          end

          private

          def resource_serializer
            Spree::Api::Dependencies.storefront_cart_serializer.constantize
          end

          def next_service
            Spree::Api::Dependencies.storefront_checkout_next_service.constantize
          end

          def advance_service
            Spree::Api::Dependencies.storefront_checkout_advance_service.constantize
          end

          def add_store_credit_service
            Spree::Api::Dependencies.storefront_checkout_add_store_credit_service.constantize
          end

          def remove_store_credit_service
            Spree::Api::Dependencies.storefront_checkout_remove_store_credit_service.constantize
          end

          def complete_service
            Spree::Api::Dependencies.storefront_checkout_complete_service.constantize
          end

          def update_service
            Spree::Api::Dependencies.storefront_checkout_update_service.constantize
          end

          def payment_methods_serializer
            Spree::Api::Dependencies.storefront_payment_method_serializer.constantize
          end

          def shipping_rates_service
            Spree::Api::Dependencies.storefront_checkout_get_shipping_rates_service.constantize
          end

          def shipping_rates_serializer
            Spree::Api::Dependencies.storefront_shipment_serializer.constantize
          end

          def create_payment_service
            Spree::Api::Dependencies.storefront_payment_create_service.constantize
          end

          def select_shipping_method_service
            Spree::Api::Dependencies.storefront_checkout_select_shipping_method_service.constantize
          end

          def serialize_payment_methods(payment_methods)
            payment_methods_serializer.new(payment_methods, params: serializer_params).serializable_hash
          end

          def serialize_shipping_rates(shipments)
            shipping_rates_serializer.new(
              shipments,
              params: serializer_params,
              include: [:shipping_rates, :stock_location, :line_items]
            ).serializable_hash
          end

          def check_if_quick_checkout
            spree_current_order.ship_address&.quick_checkout = params[:quick_checkout] if params[:quick_checkout]
          end
        end
      end
    end
  end
end
