module Spree
  class Order < Spree::Base
    module CurrencyUpdater
      extend ActiveSupport::Concern

      included do

        def homogenize_line_item_currencies
          update_line_item_currencies!
          update!
        end

      end

      # Updates prices of order's line items
      def update_line_item_currencies!
        line_items.where('currency != ?', currency).each do |line_item|
          update_line_item_price!(line_item)
        end
      end

      # Returns the price object from given item
      def price_from_line_item(line_item)
        line_item.variant.prices.where(currency: currency).first
      end

      # Updates price from given line item
      def update_line_item_price!(line_item)
        price = price_from_line_item(line_item)

        if price
          line_item.update_attributes!(currency: price.currency, price: price.amount)
        else
          raise RuntimeError, "no #{currency} price found for #{line_item.product.name} (#{line_item.variant.sku})"
        end
      end

    end
  end
end
