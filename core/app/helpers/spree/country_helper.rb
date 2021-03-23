module Spree
  module CountryHelper
    require 'twitter_cldr'

    def all_country_options
      Spree::Country.all.map { |country| country_presentation(country) }
    end

    def available_countries
      countries = current_store.countries_available_for_checkout

      localized_countries = countries.collect do |country|
        country.name = localized_country_name(country.iso)

        country
      end

      localized_countries.sort_by { |c| c.name.parameterize }
    end

    def country_presentation(country)
      [localized_country_name(country.iso), country.id]
    end

    def localized_country_name(country_iso)
      country_iso_formatted = country_iso.to_s.downcase.to_sym
      locale_formatted = current_locale.to_s.downcase.to_sym

      if I18n.exists?("spree.country_name_overide.#{country_iso_formatted}", locale: locale_formatted.to_s, fallback: false)
        return I18n.t("spree.country_name_overide.#{country_iso_formatted}", locale: locale_formatted.to_s)
      end

      country_iso_formatted.localize(locale_formatted).as_territory || Spree::Country.by_iso(country_iso)
    end
  end
end
