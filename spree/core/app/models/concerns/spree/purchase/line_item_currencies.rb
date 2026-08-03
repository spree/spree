module Spree
  module Purchase
    # Re-prices line items after a currency change, shared by Spree::Cart
    # and Spree::Order (a line item with no price in the new currency is
    # removed).
    module LineItemCurrencies
      def homogenize_line_item_currencies
        update_line_item_currencies!
        recalculate_totals!
      end

      def update_line_item_currencies!
        line_items.where.not(currency: currency).each do |line_item|
          update_line_item_price!(line_item)
        end
      end

      def price_from_line_item(line_item)
        line_item.variant.prices.where(currency: currency).first
      end

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
