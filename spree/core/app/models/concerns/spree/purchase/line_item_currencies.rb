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

      # The variant's own price in the new currency. Scoped to base prices: a
      # price list's rows belong to one audience and a ladder holds several
      # rows for one variant, so an unscoped `first` would re-price the line at
      # whichever row the database happened to return
      # (docs/plans/6.0-volume-pricing.md).
      def price_from_line_item(line_item)
        line_item.variant.prices.base_prices.where(currency: currency).first
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
