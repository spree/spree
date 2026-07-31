module Spree
  module Purchase
    # Tax location and pre-tax sums shared by Spree::Cart and Spree::Order.
    module Taxation
      # The address tax is computed against, honoring the
      # tax_using_ship_address preference.
      #
      # @return [Spree::Address, nil]
      def tax_address
        Spree::Config[:tax_using_ship_address] ? ship_address : bill_address
      end

      # @return [Spree::Zone, nil]
      def tax_zone
        @tax_zone ||= Spree::Zone.match(tax_address) || Spree::Zone.default_tax
      end

      def tax_total
        included_tax_total + additional_tax_total
      end

      # Sum of all line item amounts pre-tax
      def pre_tax_item_amount
        line_items.sum(:pre_tax_amount)
      end

      # Sum of all line item and fulfillment amounts pre-tax
      def pre_tax_total
        pre_tax_item_amount + fulfillments.sum(:pre_tax_amount)
      end
    end
  end
end
