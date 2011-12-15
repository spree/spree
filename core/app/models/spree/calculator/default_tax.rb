module Spree
  class Calculator::DefaultTax < Calculator
    def self.description
      I18n.t(:default_tax)
    end

    def compute(order)
      #rate = self.calculable
      #tax = 0

      #if rate.tax_category.is_default
        #order.adjustments.each do |adjust|
          #next if adjust.originator_type == 'Spree::TaxRate'
          #next if adjust.originator_type == 'Spree::ShippingMethod' and not Spree::Config[:shipment_inc_vat]

          #tax += (adjust.amount * rate.amount).round(2, BigDecimal::ROUND_HALF_UP)
        #end
      #end

      #order.line_items.each do  | line_item|
        #if line_item.product.tax_category  #only apply this calculator to products assigned this rates category
          #next unless line_item.product.tax_category == rate.tax_category
        #else
          #next unless rate.tax_category.is_default # and apply to products with no category, if this is the default rate
        #end
        #tax += (line_item.price * rate.amount).round(2, BigDecimal::ROUND_HALF_UP) * line_item.quantity
      #end

      #tax
    end
  end
end
