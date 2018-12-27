module Spree
  module Api
    module V2
      module Storefront
        class CheckoutController < ::Spree::Api::V2::BaseController
          before_action :ensure_order

          def next
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:next_state_handler].call(order: spree_current_order)

            render_order(result)
          end

          def advance
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:advance_handler].call(order: spree_current_order)

            render_order(result)
          end

          def complete
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:completer].call(order: spree_current_order)

            render_order(result)
          end

          def update
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:updater].call(
              order: spree_current_order,
              params: params,
              permitted_attributes: dependencies[:permitted_attributes],
              request_env: request.headers.env
            )

            render_order(result)
          end

          def add_store_credit
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:add_store_credit_handler].call(
              order: spree_current_order,
              amount: params[:amount].try(:to_f)
            )

            render_order(result)
          end

          def remove_store_credit
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:remove_store_credit_handler].call(order: spree_current_order)
            render_order(result)
          end

          def shipping_rates
            result = dependencies[:shipping_rates_getter].call(order: spree_current_order)

            render_serialized_payload { serialize_shipping_rates(result.value) }
          end

          def payment_methods
            render_serialized_payload { serialize_payment_methods(spree_current_order.available_payment_methods) }
          end

          private

          def ensure_order
            raise ActiveRecord::RecordNotFound if spree_current_order.nil?
          end

          def dependencies
            {
              next_state_handler: Spree::Checkout::Next,
              advance_handler: Spree::Checkout::Advance,
              add_store_credit_handler: Spree::Checkout::AddStoreCredit,
              remove_store_credit_handler: Spree::Checkout::RemoveStoreCredit,
              completer: Spree::Checkout::Complete,
              updater: Spree::Checkout::Update,
              cart_serializer: Spree::V2::Storefront::CartSerializer,
              payment_methods_serializer: Spree::V2::Storefront::PaymentMethodSerializer,
              shipping_rates_getter: Spree::Checkout::GetShippingRates,
              shipping_rates_serializer: Spree::V2::Storefront::ShipmentSerializer,
              # defined in https://github.com/spree/spree/blob/master/core/lib/spree/core/controller_helpers/strong_parameters.rb#L19
              permitted_attributes: permitted_checkout_attributes
            }
          end

          def render_order(result)
            if result.success?
              render_serialized_payload { serialize_order(result.value) }
            else
              render_error_payload(result.error)
            end
          end

          def serialize_order(order)
            dependencies[:cart_serializer].new(order.reload, include: resource_includes, fields: sparse_fields).serializable_hash
          end

          def serialize_payment_methods(payment_methods)
            dependencies[:payment_methods_serializer].new(payment_methods).serializable_hash
          end

          def serialize_shipping_rates(shipments)
            dependencies[:shipping_rates_serializer].new(
              shipments,
              include: [:shipping_rates],
              params: { show_rates: true }
            ).serializable_hash
          end

          def default_resource_includes
            %i[
              line_items
              variants
              promotions
            ]
          end
        end
      end
    end
  end
end
