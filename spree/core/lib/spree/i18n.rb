require 'i18n'

module Spree
  SHIPPED_LOCALES = Dir[File.expand_path('../../config/locales/*.yml', __dir__)].map { |file| File.basename(file, '.yml').to_sym }.freeze

  class << self
    # @deprecated Use +I18n.t+ with the full key, e.g. +I18n.t('spree.free')+.
    #   Will be removed in Spree 6.1.
    def translate(key, options = {})
      Spree::Deprecation.warn('Spree.t is deprecated and will be removed in Spree 6.1. Use I18n.t with the full key, e.g. I18n.t("spree.free").') if defined?(Spree::Deprecation)

      I18n.t(key, **options.symbolize_keys, scope: [:spree, *Array(options[:scope]).map(&:to_sym)].uniq)
    end
    alias t translate

    # Locales Spree ships translations for that the app allows, plus English
    # and the app's default and current locale.
    #
    # @return [Array<Symbol>]
    def available_locales
      (configured_locales & I18n.available_locales.map(&:to_sym)) | [:en, I18n.locale, Rails.application.config.i18n.default_locale].compact
    end

    # {available_locales} as read from configuration alone, without loading
    # any translations, for use while the app boots.
    #
    # @return [Array<Symbol>]
    def configured_locales
      allowed = Array(Rails.application.config.i18n.available_locales).map(&:to_sym)
      allowed.empty? ? SHIPPED_LOCALES : SHIPPED_LOCALES & allowed
    end

    # The available locale a store should use for a language: the language
    # itself when Spree ships it, otherwise its first regional variant ("zh"
    # becomes "zh-CN", since Spree ships Chinese only by region).
    #
    # @param language [String] ISO 639-1 code, e.g. "de"
    # @param locales [Array<Symbol>] the locales to choose from
    # @return [String, nil] nil when the language is not available at all
    def locale_for_language(language, locales = available_locales)
      codes = locales.map(&:to_s)
      return language if codes.include?(language)

      codes.sort.find { |code| code.start_with?("#{language}-") }
    end
  end
end
