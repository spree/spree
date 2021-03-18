module Spree
  module CountryHelper
    require 'twitter_cldr'

    def all_country_options(countries, requested_locale)
      countries.map { |country| country_presentation(country, requested_locale) }
    end

    def country_presentation(country, requested_locale)
      [localized_country_name(country.iso, requested_locale), country.id]
    end

    # Localizes the county names to the current_locale.
    def localized_country_name(country_iso)
      country_iso_formatted = country_iso.to_s.downcase.to_sym
      locale_formatted = current_locale.to_s.downcase.to_sym

      # Allows a user to override the Country name on a per Country, per Language basis.
      if I18n.exists?("spree.country_name_overide.#{country_iso_formatted}", locale: locale_formatted.to_s, fallback: false)
        return I18n.t("spree.country_name_overide.#{country_iso_formatted}", locale: locale_formatted.to_s)
      end

      # Falls back to pulling the country name from the DB.
      country_iso_formatted.localize(locale_formatted).as_territory || Spree::Country.find_by(iso: country_iso)
    end
  end
end
