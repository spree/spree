module Spree
  module ReportLineItems
    class SalesTotal < Spree::ReportLineItem
      attribute :date, :string
      attribute :order, :string
      attribute :product, :string
      attribute :pre_tax_amount, :decimal
      attribute :discount, :decimal
      attribute :shipping, :decimal
      attribute :tax, :decimal
      attribute :total, :decimal

      def date
        record.order.completed_at.strftime('%Y-%m-%d')
      end

      def order
        record.order.number
      end

      def product
        record.variant.descriptive_name
      end

      def total
        Spree::Money.new(record.final_amount + record.shipping_cost, currency: record.currency)
      end

      def discount
        record.display_promo_total
      end

      def pre_tax_amount
        record.display_pre_tax_amount
      end

      def shipping
        record.display_shipping_cost
      end

      def tax
        record.display_tax_total
      end
    end
  end
end
