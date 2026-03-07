module Spree
  module Variants
    class Update
      prepend Spree::ServiceModule::Base

      def call(variant:, params:)
        ApplicationRecord.transaction do
          run :update_variant
          run :sync_prices
          run :sync_stock
        end
      end

      private

      def update_variant(variant:, params:)
        params = params.to_h.with_indifferent_access
        @prices_params = params.delete(:prices)
        @stock_items_params = params.delete(:stock_items)
        option_type_name = params.delete(:option_type)
        option_value_name = params.delete(:option_value)

        # When explicit prices are provided, remove shortcut attrs to avoid conflicts
        if @prices_params
          params.delete(:price)
          params.delete(:compare_at_price)
          params.delete(:currency)
        end

        if option_type_name.present? && option_value_name.present?
          variant.set_option_value(option_type_name, option_value_name)
        end

        if variant.update(params)
          success(variant: variant)
        else
          failure(variant, variant.errors)
        end
      end

      def sync_prices(variant:)
        return success(variant: variant) unless @prices_params

        currencies_in_payload = []

        @prices_params.each do |price_data|
          price_data = price_data.to_h.with_indifferent_access
          currencies_in_payload << price_data[:currency]
          variant.set_price(price_data[:currency], price_data[:amount], price_data[:compare_at_amount])
        end

        # Soft-delete prices for currencies not in the payload
        variant.prices.base_prices.where.not(currency: currencies_in_payload).destroy_all

        success(variant: variant.reload)
      end

      def sync_stock(variant:)
        return success(variant: variant) unless @stock_items_params

        location_ids_in_payload = []

        @stock_items_params.each do |stock_data|
          stock_data = stock_data.to_h.with_indifferent_access
          location = Spree::StockLocation.find_by_prefix_id!(stock_data[:stock_location_id])
          location_ids_in_payload << location.id
          variant.set_stock(stock_data[:count_on_hand], stock_data[:backorderable], location)
        end

        # Soft-delete stock items for locations not in the payload
        variant.stock_items.where.not(stock_location_id: location_ids_in_payload).update_all(deleted_at: Time.current)

        success(variant: variant.reload)
      end
    end
  end
end
