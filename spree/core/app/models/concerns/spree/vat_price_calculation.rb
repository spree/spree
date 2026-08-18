module Spree
  # Restates a VAT-inclusive price for a customer in another country: the
  # home-country VAT comes out, the destination's goes on.
  module VatPriceCalculation
    # Cheapest test first: a domestic sale needs no restatement whatever the
    # provider is, so the provider lookup (a constantize and an instantiation) is
    # skipped for every home-country price — and a market pointing at a provider
    # class that is no longer loadable keeps failing only where tax is computed,
    # not on every price read.
    def gross_amount(amount, price_options)
      return amount if amount.nil? || !outside_default_vat_zone?(price_options)
      return amount unless restatement_available?(price_options)

      round_to_two_places(add_foreign_vat_for(amount, price_options))
    end

    private

    # Restatement reads nothing but TaxRate rows, for both halves of the sum, so
    # it only means anything where those rows are the whole truth — the Internal
    # provider. Elsewhere an absent row is ambiguous: it reads as "no tax is due
    # here" and deducts the home VAT, when it may only mean "this market's tax is
    # computed by an engine that keeps no rows here". A market on such an engine
    # would see every foreign destination treated as a zero-rated export. It
    # states its destination prices through a geo-scoped price list instead.
    def restatement_available?(price_options)
      market = price_options[:market] || Spree::Current.market
      provider = market&.tax_provider_instance || Spree.default_tax_provider.new

      provider.is_a?(Spree::TaxProvider::Internal)
    end

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

    # Whether the price has to be restated at all.
    def outside_default_vat_zone?(price_options)
      country = country_from(price_options)

      country.present? && default_tax_country.present? && country != default_tax_country
    end

    def included_tax_amount(price_options)
      lookup = { tax_category: price_options[:tax_category] }
      if price_options[:address]
        lookup[:address] = price_options[:address]
      else
        lookup[:country] = country_from(price_options)
      end

      Spree::TaxRate.included_tax_amount_for(lookup).to_f
    end

    # +current_price_options+ is documented as an override point, so an app may
    # still be handing us the pre-6.0 zone. Say so instead of quietly reporting
    # no country, which would leave a foreign customer looking at home VAT.
    def country_from(price_options)
      if price_options[:tax_zone].present? && price_options[:country].blank? && price_options[:address].blank?
        Spree::Deprecation.warn(
          'Passing tax_zone: in price options no longer determines tax and is ignored. ' \
          'Pass country: (a Spree::Country) or address: instead.'
        )
      end

      price_options[:country] || price_options[:address]&.country
    end

    # The country whose VAT the catalogue prices already include. Deliberately
    # the store's own country and NOT Spree::Current.market, which follows the
    # buyer: reading the destination here would make every sale look domestic
    # and the restatement would never fire.
    def default_tax_country
      return @default_tax_country if defined?(@default_tax_country)

      @default_tax_country = Spree::Current.store&.default_country
    end

    def round_to_two_places(amount)
      Spree::Money::Rounding.quantize(amount, 2)
    end
  end
end
