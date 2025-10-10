module Spree
  class Order < Spree.base_class
    module CurrencyUpdater
      extend ActiveSupport::Concern # FIXME: this module is not required to be a concern

      included do
        def homogenize_line_item_currencies
          update_line_item_currencies!
          update_with_updater!
        end
      end

      # Updates prices of order's line items
      def update_line_item_currencies!
        line_items.where.not(currency: currency).each do |line_item|
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

        if price&.currency && price.amount
          line_item.update!(currency: price.currency, price: price.amount)
        else
          line_item.destroy
        end
      end
    end
  end
end
