module Spree
  module Api
    module V2
      module Storefront
        class CheckoutController < ::Spree::Api::V2::BaseController
          def next
            spree_authorize! :update, spree_current_order, order_token

            dependencies[:next_state_procceder].new(spree_current_order).call

            render_order spree_current_order
          end

          def advance
            spree_authorize! :update, spree_current_order, order_token

            dependencies[:advance_proceeder].new(spree_current_order).call

            render_order spree_current_order
          end

          def complete
            spree_authorize! :update, spree_current_order, order_token

            dependencies[:completer].new(spree_current_order).call

            render_order spree_current_order
          end

          def update
            spree_authorize! :update, spree_current_order, order_token
            result = dependencies[:updater].call(
              order: spree_current_order,
              params: params,
              request_env: request.headers.env
            )

            if result.success?
              render_serialized_payload serialize_order(result.value), 200
            else
              render_serialized_payload result.value, 422
            end
          end

          private

          def dependencies
            {
              next_state_procceder: Spree::Checkout::Next,
              advance_proceeder:    Spree::Checkout::Advance,
              completer:            Spree::Checkout::Complete,
              updater:              Spree::Checkout::Update,
              cart_serializer:      Spree::V2::Storefront::CartSerializer
            }
          end

          def render_order(order)
            if order.errors.present?
              render_serialized_payload order.errors, 422
            else
              render_serialized_payload serialize_order(order)
            end
          end

          def serialize_order(order)
            dependencies[:cart_serializer].new(order.reload, include: resource_includes).serializable_hash
          end

          def resource_includes
            request_includes || default_resource_includes
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
