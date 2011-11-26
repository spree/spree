module Spree
  class Calculator::Vat < Calculator
    def self.description
      I18n.t(:vat)
    end

    def self.calculate_tax_on(taxable)
      # taxable may be product or variant
      taxable = taxable.product if taxable.respond_to?(:product)
      (taxable.price * taxable.effective_tax_rate).round(2, BigDecimal::ROUND_HALF_UP)
    end

    # computes vat for line_items associated with order, and tax rate and
    # now coupon discounts are taken into account in tax calcs
    # and tax is added to shipment if :shipment_inc_vat is set
    # coupons and shipment are applied if this object is the rate for the default category
    #           (also items with no category get this rate applied)
    def compute(order)
      rate = self.calculable
      tax = 0

      if rate.tax_category.is_default
        order.adjustments.each do |adjust|
          next if adjust.originator_type == 'Spree::TaxRate'
          next if adjust.originator_type == 'Spree::ShippingMethod' and not Spree::Config[:shipment_inc_vat]

          tax += (adjust.amount * rate.amount).round(2, BigDecimal::ROUND_HALF_UP)
        end
      end

      order.line_items.each do  | line_item|
        if line_item.product.tax_category  #only apply this calculator to products assigned this rates category
          next unless line_item.product.tax_category == rate.tax_category
        else
          next unless rate.tax_category.is_default # and apply to products with no category, if this is the default rate
        end
        tax += (line_item.price * rate.amount).round(2, BigDecimal::ROUND_HALF_UP) * line_item.quantity
      end

      tax
    end
  end
end
