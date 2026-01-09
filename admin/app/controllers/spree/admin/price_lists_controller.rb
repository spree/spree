module Spree
  module Admin
    class PriceListsController < ResourceController
      include ProductsBreadcrumbConcern

      # GET /admin/price_lists/:price_list_id/edit_prices
      def edit_prices
        @currency = params[:currency] || current_store.default_currency
        @currency_symbol = ::Money::Currency.find(@currency).symbol
        @prices = @price_list.prices.
                  includes(variant: [:product, { option_values: :option_type }]).
                  where(currency: @currency).
                  joins(variant: :product).
                  order("#{Spree::Product.table_name}.name ASC", "#{Spree::Variant.table_name}.position ASC")
      end

      private

      def location_after_save
        spree.admin_price_list_path(@price_list)
      end

      def update_turbo_stream_enabled?
        true
      end

      def permitted_resource_params
        params.require(:price_list).permit(
          permitted_price_list_attributes,
          prices_attributes: [:id, :variant_id, :currency, :amount, :compare_at_amount]
        )
      end
    end
  end
end
