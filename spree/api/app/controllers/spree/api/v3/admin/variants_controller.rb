module Spree
  module Api
    module V3
      module Admin
        class VariantsController < ResourceController
          scoped_resource :products

          SALES_CONTEXT_PARAMS = %i[order_id market_id channel_id customer_id company_id].freeze

          # A draft order's item picker asks with the order's market, channel and
          # buyer, so it lists only what that buyer can be sold there, priced as
          # they would pay.
          before_action :load_sales_context, only: :index

          protected

          def model_class
            Spree::Variant
          end

          def serializer_class
            Spree.api.admin_variant_serializer
          end

          # Chains onto the base scope rather than replacing it: building the
          # relation from scratch dropped `scope_includes`, so every listed
          # variant fell back to per-row price and stock queries.
          def scope
            variants = super.eligible.accessible_by(current_ability, ability_action_for_request)
            @sales_context ? variants.merge(@sales_context.sellable_variants) : variants
          end

          def serializer_params
            return super unless @sales_context

            super.merge(
              currency: @sales_context.currency,
              user: @sales_context.customer,
              company: @sales_context.company,
              market: @sales_context.market,
              channel: @sales_context.channel
            )
          end

          # `active_stock_reservations` rides along with the stock levels:
          # without it the quantifier falls back to a SUM per variant, which
          # is the whole cost of listing variants.
          def scope_includes
            [
              :prices,
              { stock_levels: [:stock_location, :active_stock_reservations] },
              { option_values: :option_type },
              { primary_media: [{ attachment_attachment: :blob }, { poster_attachment: :blob }] }
            ]
          end

          private

          def load_sales_context
            return if SALES_CONTEXT_PARAMS.none? { |key| params[key].present? }

            permission = required_sales_context_permission
            return deny_missing_permission(permission) if permission && !holds_permission?(permission)

            if params[:order_id].present?
              @sales_context = Spree::SalesContext.from_order(context_order)
            else
              @sales_context = requested_sales_context
              render_errors(@sales_context.errors) unless @sales_context.valid?
            end
          end

          def required_sales_context_permission
            return 'read_orders' if params[:order_id].present?

            'read_customers' if params[:customer_id].present? || params[:company_id].present?
          end

          def requested_sales_context
            Spree::SalesContext.new(
              store: current_store,
              market: find_requested(current_store.markets, :market_id),
              channel: find_requested(current_store.channels, :channel_id),
              customer: find_requested(Spree.customer_class.accessible_by(current_ability, :show), :customer_id),
              company: find_requested(current_store.companies, :company_id),
              currency: params[:currency]
            )
          end

          def find_requested(relation, key)
            relation.find_by_prefix_id!(params[key]) if params[key].present?
          end

          def context_order
            current_store.orders.accessible_by(current_ability, :show).find_by_prefix_id!(params[:order_id])
          end

          def deny_missing_permission(permission)
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: "Missing permission: #{permission}",
              status: :forbidden,
              details: { required_permission: permission }
            )
          end
        end
      end
    end
  end
end
