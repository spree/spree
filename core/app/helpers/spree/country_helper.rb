module Spree
  module CountryHelper
    require 'twitter_cldr'

    def all_country_options(countries, requested_locale)
      countries.map { |country| country_presentation(country, requested_locale) }
    end

    def country_presentation(country, requested_locale)
      [localized_country_name(country.iso, requested_locale), country.id]
    end

    # Localizes the county names to the requested language
    #
    # Example:
    #
    #   localized_country_name('GB', 'de') # => Vereinigtes Konigreich
    #   localized_country_name('GB', 'en') # => England
    def localized_country_name(country_iso, locale)
      # TODO: Write checks and fallbacks think if there would be a default best case
      country_iso_formatted = country_iso.to_s.downcase.to_sym
      locale_formatted = locale.to_s.downcase.to_sym

      country_iso_formatted.localize(locale_formatted).as_territory
    end
  end
end
