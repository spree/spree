module Spree
  module Variants
    class Create
      prepend Spree::ServiceModule::Base

      def call(product:, params:)
        ApplicationRecord.transaction do
          run :create_variant
          run :sync_prices
          run :set_stock
        end
      end

      private

      def create_variant(product:, params:)
        params = params.to_h.with_indifferent_access
        @prices_params = params.delete(:prices)
        @stock_items_params = params.delete(:stock_items)
        option_type_name = params.delete(:option_type)
        option_value_name = params.delete(:option_value)

        variant = product.variants.build(params)

        if option_type_name.present? && option_value_name.present?
          variant.set_option_value(option_type_name, option_value_name)
        end

        if variant.save
          success(variant: variant)
        else
          failure(variant, variant.errors)
        end
      end

      def sync_prices(variant:)
        return success(variant: variant) if @prices_params.blank?

        @prices_params.each do |price_data|
          price_data = price_data.to_h.with_indifferent_access
          variant.set_price(price_data[:currency], price_data[:amount], price_data[:compare_at_amount])
        end

        success(variant: variant.reload)
      end

      def set_stock(variant:)
        return success(variant: variant) if @stock_items_params.blank?

        @stock_items_params.each do |stock_data|
          stock_data = stock_data.to_h.with_indifferent_access
          location = Spree::StockLocation.find_by_prefix_id!(stock_data[:stock_location_id])
          variant.set_stock(stock_data[:count_on_hand], stock_data[:backorderable], location)
        end

        success(variant: variant.reload)
      end
    end
  end
end
