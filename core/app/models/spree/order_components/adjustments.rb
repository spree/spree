require_relative 'line_items'

module Spree
  module OrderComponents
    module Adjustments
      def self.included(base)
        base.class_eval do
          include Spree::OrderComponents::LineItems
          after_create :create_tax_charge!
          has_many :adjustments, :as => :adjustable, :dependent => :destroy, :order => "created_at ASC"
        end
      end

      # Array of adjustments that are inclusive in the variant price.  Useful for when prices
      # include tax (ex. VAT) and you need to record the tax amount separately.
      def price_adjustments
        line_items.inject([]) do |adjustments, line_item|
          adjustments += line_item.adjustments
        end
      end

      # Array of totals grouped by Adjustment#label.  Useful for displaying price adjustments on an
      # invoice.  For example, you can display tax breakout for cases where tax is included in price.
      def price_adjustment_totals
        totals = {}

        price_adjustments.each do |adjustment|
          label = adjustment.label
          totals[label] ||= 0
          totals[label] = totals[label] + adjustment.amount
        end

        totals
      end

      def ship_total
        adjustments.shipping.map(&:amount).sum
      end

      def tax_total
        adjustments.tax.map(&:amount).sum
      end

      # destroy any previous adjustments.
      # Adjustments will be recalculated during order update.
      def clear_adjustments!
        adjustments.tax.each(&:destroy)
        price_adjustments.each(&:destroy)
      end

      private
      # Creates new tax charges if there are any applicable rates. If prices already
      # include taxes then price adjustments are created instead.
      def create_tax_charge!
        Spree::TaxRate.adjust(self)
      end

    end
  end
end
