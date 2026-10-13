module Spree
  module Api
    module V3
      module Admin
        class VariantsController < ResourceController
          scoped_resource :products

          before_action :set_sales_context, only: :index

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
            return variants unless sales_context?

            variants.for_products(sellable_products)
          end

          def serializer_params
            return super unless sales_context?

            super.merge(user: context_customer, company: context_company)
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

          # A draft order's item picker passes the order's market, channel and
          # buyer, so the list holds only what that buyer can be sold there,
          # priced as they would pay.
          def sales_context?
            params[:market_id].present? || params[:channel_id].present?
          end

          def set_sales_context
            return unless sales_context?

            if params[:market_id].present?
              Spree::Current.market = current_store.markets.find_by_prefix_id!(params[:market_id])
              Spree::Current.currency = @current_currency = Spree::Current.market.currency if params[:currency].blank?
            end
            Spree::Current.channel = current_store.channels.find_by_prefix_id!(params[:channel_id]) if params[:channel_id].present?
          end

          def sellable_products
            Spree.products_for_context_service.call(
              store: current_store,
              channel: Spree::Current.channel,
              customer: context_customer,
              company: context_company,
              base: current_store.products.available(Time.current, Spree::Current.currency)
            ).value
          end

          def context_customer
            return if params[:customer_id].blank?

            @context_customer ||= Spree.customer_class.accessible_by(current_ability, :show).find_by_prefix_id!(params[:customer_id])
          end

          def context_company
            return if params[:company_id].blank?

            @context_company ||= current_store.companies.find_by_prefix_id!(params[:company_id])
          end
        end
      end
    end
  end
end
