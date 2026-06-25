# frozen_string_literal: true

require 'countries'

module Spree
  # Localized display names for countries, currencies, and locales.
  #
  # Country names come from the +countries+ gem (CLDR translations). Currency and
  # language names fall back to the Money gem and Spree I18n bundles; the admin
  # Stimulus +display-name+ controller upgrades labels client-side via
  # +Intl.DisplayNames+ when available — matching the React dashboard.
  module DisplayNames
    module_function

    # @param code [String, Symbol]
    # @param name [String]
    # @return [String] e.g. "EN — English"
    def format_code_name(code, name)
      upper = code.to_s.upcase
      label = name.to_s
      return upper if label.blank? || label.casecmp?(code.to_s)

      "#{upper} — #{label}"
    end

    # @param iso [String]
    # @param locale [Symbol, String]
    # @param fallback [String, nil]
    # @return [String]
    def country_name(iso, locale: I18n.locale, fallback: nil)
      iso = iso.to_s.upcase
      fallback ||= iso

      data = ISO3166::Country[iso]
      return fallback unless data

      translation = data.translation(display_locale(locale)) || data.translation(:en)
      translation.presence || data.common_name || fallback
    end

    # @param country [Spree::Country]
    # @param locale [Symbol, String]
    # @return [String]
    def country_option_label(country, locale: I18n.locale)
      name = country_name(country.iso, locale: locale, fallback: country.name)
      "#{Spree::Country.iso_to_emoji_flag(country.iso)} #{name}"
    end

    # @param code [String]
    # @param locale [Symbol, String]
    # @return [String]
    def currency_name(code, locale: I18n.locale)
      Money::Currency.find(code.to_s.upcase).name
    rescue Money::Currency::UnknownCurrency
      code.to_s.upcase
    end

    # @param code [String]
    # @param locale [Symbol, String]
    # @return [String]
    def currency_label(code, locale: I18n.locale)
      format_code_name(code, currency_name(code, locale: locale))
    end

    # @param code [String, Symbol]
    # @param locale [Symbol, String]
    # @return [String]
    def language_name(code, locale: I18n.locale)
      code = code.to_s

      if I18n.exists?('spree.i18n.this_file_language', locale: code, fallback: false)
        return normalize_language_name(Spree.t('i18n.this_file_language', locale: code))
      end

      if defined?(SpreeI18n::Locale) && (name = SpreeI18n::Locale.local_language_name(code))
        return normalize_language_name(name)
      end

      return 'English' if code == 'en'

      code
    end

    # @param code [String, Symbol]
    # @param locale [Symbol, String]
    # @return [String]
    def locale_label(code, locale: I18n.locale)
      format_code_name(code, language_name(code, locale: locale))
    end

    # @param locale [Symbol, String]
    # @return [String]
    def display_locale(locale)
      locale.to_s.downcase.tr('_', '-').split('-').first
    end

    # Strip a trailing " (CODE)" suffix from Spree I18n locale labels.
    # @param name [String]
    # @return [String]
    def normalize_language_name(name)
      name.to_s.sub(/\s*\([^)]+\)\z/, '')
    end
  end
end
