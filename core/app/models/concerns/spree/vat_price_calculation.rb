module Spree
  module VatPriceCalculation
    def gross_amount(amount, zone, tax_category)
      return amount unless outside_default_vat_zone?(zone)
      round_to_two_places(add_foreign_vat_for(amount, zone, tax_category))
    end

    private

    def add_foreign_vat_for(amount, zone, tax_category)
      amount = net_amount(amount, tax_category)
      amount_with_foreign_vat(amount, zone, tax_category)
    end

    def net_amount(amount, tax_category)
      amount / (1 + included_tax_amount(default_zone, tax_category))
    end

    def amount_with_foreign_vat(amount, zone, tax_category)
      amount * (1 + included_tax_amount(zone, tax_category))
    end

    def outside_default_vat_zone?(zone)
      zone && default_zone && zone != default_zone
    end

    def included_tax_amount(zone, tax_category)
      Spree::TaxRate.included_tax_amount_for(zone, tax_category).to_f
    end

    def default_zone
      @_default_zone ||= Spree::Zone.default_tax
    end

    def round_to_two_places(amount)
      BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
    end
  end
end
