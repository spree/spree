module Spree
  module VatPriceCalculation
    def gross_amount(amount, price_options)
      return amount unless outside_default_vat_zone?(price_options)
      round_to_two_places(add_foreign_vat_for(amount, price_options))
    end

    private

    def add_foreign_vat_for(amount, price_options)
      amount = net_amount(amount, price_options[:tax_category])
      amount_with_foreign_vat(amount, price_options)
    end

    def net_amount(amount, tax_category)
      amount / (1 + default_vat(tax_category))
    end

    def default_vat(tax_category)
      included_tax_amount(tax_zone: default_zone, tax_category: tax_category)
    end

    def foreign_vat(price_options)
      included_tax_amount(price_options)
    end

    def amount_with_foreign_vat(amount, price_options)
      amount * (1 + foreign_vat(price_options))
    end

    def outside_default_vat_zone?(price_options)
      price_options[:tax_zone] && default_zone && price_options[:tax_zone] != default_zone
    end

    def included_tax_amount(price_options)
      Spree::TaxRate.included_tax_amount_for(price_options).to_f
    end

    def default_zone
      @_default_zone ||= Spree::Zone.default_tax
    end

    def round_to_two_places(amount)
      BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
    end
  end
end
