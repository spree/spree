module Spree
  module Variants
    # Applies the nested data a variant write can carry: its option values,
    # its prices and its stock levels. Shared by Spree::Variants::Create and
    # ::Update so both write paths reconcile them the same way.
    #
    # All three go through the model's own writers (`set_option_value`,
    # `set_price`, `set_stock`) rather than touching rows directly. That is
    # deliberate: `set_price` reuses the loaded prices association so a
    # response serialized in the same request sees the write, and `set_stock`
    # routes a count change through a stock movement so it lands in the
    # history like every other adjustment.
    #
    # The three payloads do not share one nullability contract, because the
    # records do not carry the same risk:
    #
    # * `prices` is a full replacement — a currency missing from the payload
    #   loses its base price, and `[]` clears every one.
    # * `stock_levels` is upsert-only. Dropping a warehouse from a payload
    #   must not silently destroy its stock: the count is a fact about a
    #   shelf, with a movement history behind it, and a partial payload is
    #   far likelier than an instruction to zero a warehouse.
    # * `options` is upsert-only, matching what the model has always done.
    module NestedAttributes
      extend ActiveSupport::Concern

      private

      # @param variant [Spree::Variant]
      # @param options_params [Array<Hash>, nil]
      # @return [void]
      def apply_options(variant, options_params)
        return if options_params.blank?

        options_params.each do |raw|
          option = raw.to_h.with_indifferent_access
          next if option[:name].blank? || option[:value].blank?

          variant.set_option_value(option[:name], option[:value], option[:position])
        end
      end

      # @param variant [Spree::Variant]
      # @param prices_params [Array<Hash>, nil] nil leaves prices alone; an
      #   empty array clears every base price
      # @return [void]
      def apply_prices(variant, prices_params)
        return if prices_params.nil?

        currencies = []

        Array(prices_params).each do |raw|
          price = raw.to_h.with_indifferent_access
          next if price[:currency].blank?

          currencies << price[:currency]
          variant.set_price(price[:currency], price[:amount], price[:compare_at_amount])
        end

        return unless variant.persisted?

        variant.prices.base_prices.where.not(currency: currencies).destroy_all
      end

      # @param variant [Spree::Variant]
      # @param stock_levels_params [Array<Hash>, nil]
      # @return [void]
      def apply_stock_levels(variant, stock_levels_params)
        return if stock_levels_params.blank?

        Array(stock_levels_params).each do |raw|
          row = raw.to_h.with_indifferent_access
          next if row[:stock_location_id].blank?

          # Scoped through the product's own store: Spree::StockLocation
          # lookup is global, so an id belonging to another store would
          # otherwise put this variant's stock in that store's warehouse.
          location = stock_location_for(variant, row[:stock_location_id])
          next if location.nil?

          variant.set_stock(row[:count_on_hand], row[:backorderable], location)
        end
      end

      def stock_location_for(variant, param)
        variant.product&.store&.stock_locations&.find_by_param(param)
      end
    end
  end
end
