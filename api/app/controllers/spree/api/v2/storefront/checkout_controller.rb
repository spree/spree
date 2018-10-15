module Spree
  module Api
    module V2
      module Storefront
        class CheckoutController < ::Spree::Api::V2::BaseController
          def next
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:next_state_procceder].call(order: spree_current_order)

            render_order(result)
          end

          def advance
            spree_authorize! :update, spree_current_order, order_token

            result = dependencies[:advance_proceeder].call(order: spree_current_order)

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

          private

          def dependencies
            {
              next_state_procceder: Spree::Checkout::Next,
              advance_proceeder:    Spree::Checkout::Advance,
              completer:            Spree::Checkout::Complete,
              updater:              Spree::Checkout::Update,
              cart_serializer:      Spree::V2::Storefront::CartSerializer,
              # defined in https://github.com/spree/spree/blob/master/core/lib/spree/core/controller_helpers/strong_parameters.rb#L19
              permitted_attributes: permitted_checkout_attributes
            }
          end

          def render_order(result)
            if result.success?
              render_serialized_payload serialize_order(result.value)
            else
              render_error_payload(result.error)
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
