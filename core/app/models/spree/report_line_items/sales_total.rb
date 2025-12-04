module Spree
  module ReportLineItems
    class SalesTotal < Spree::ReportLineItem
      add_report_attributes :sales_total

      delegate :quantity, to: :record

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

      def promo_total
        record.display_promo_total
      end

      def pre_tax_amount
        record.display_pre_tax_amount
      end

      def shipment_total
        record.display_shipping_cost
      end

      def tax_total
        record.display_tax_total
      end
    end
  end
end
