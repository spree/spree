module Spree
  # Restates a VAT-inclusive price for a customer in another country: the
  # home-country VAT comes out, the destination's goes on.
  module VatPriceCalculation
    def gross_amount(amount, price_options)
      return amount if amount.nil? || !outside_default_vat_zone?(price_options)

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
      included_tax_amount(country: default_tax_country, tax_category: tax_category)
    end

    def foreign_vat(price_options)
      included_tax_amount(price_options)
    end

    def amount_with_foreign_vat(amount, price_options)
      amount * (1 + foreign_vat(price_options))
    end

    # Whether the price has to be restated at all. The zone in price_options is
    # the browsing context's; what matters for tax is the country behind it.
    def outside_default_vat_zone?(price_options)
      country = country_from(price_options)

      country.present? && default_tax_country.present? && country != default_tax_country
    end

    def included_tax_amount(price_options)
      country = price_options[:country] || country_from(price_options)

      Spree::TaxRate.included_tax_amount_for(
        country: country, tax_category: price_options[:tax_category]
      ).to_f
    end

    def country_from(price_options)
      return price_options[:country] if price_options[:country]
      return price_options[:address].country if price_options[:address]

      # A zone can span several countries; its own country list is the only
      # thing to read, and a single-country zone is the case that matters here.
      zone = price_options[:tax_zone]
      zone&.countries&.first
    end

    # The country whose VAT the catalogue prices already include — the market
    # being browsed, or the store's own country when there is no market.
    def default_tax_country
      return @default_tax_country if defined?(@default_tax_country)

      @default_tax_country = Spree::Current.market&.default_country || Spree::Current.store&.default_country
    end

    def round_to_two_places(amount)
      BigDecimal(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
    end
  end
end
