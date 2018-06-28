module Spree
  class VatPriceCalculator
    def call(amount, price_options)
      return amount unless outside_default_vat_zone?(price_options)
      BigDecimal.new(amount_with_foreign_vat(amount, price_options).to_s).round(2, BigDecimal::ROUND_HALF_UP)
    end

    private

    def amount_with_foreign_vat(amount, price_options)
      included_tax = included_tax_amount(tax_zone: default_zone, tax_category: price_options[:tax_category])
      net_amount = amount / (1 + included_tax)
      net_amount * (1 + included_tax_amount(price_options))
    end

    def outside_default_vat_zone?(price_options)
      price_options[:tax_zone] && default_zone && price_options[:tax_zone] != default_zone
    end

    def included_tax_amount(price_options)
      Spree::TaxRate.included_tax_amount_for(price_options).to_f
    end

    def default_zone
      @default_zone ||= Spree::Zone.default_tax
    end
  end
end
