require 'i18n'

module Spree
  SHIPPED_LOCALES = Dir[File.expand_path('../../config/locales/*.yml', __dir__)].map { |file| File.basename(file, '.yml').to_sym }.freeze

  class << self
    # @deprecated Use +I18n.t+ with the full key, e.g. +I18n.t('spree.free')+.
    #   Will be removed in Spree 6.1.
    def translate(key, options = {})
      Spree::Deprecation.warn('Spree.t is deprecated and will be removed in Spree 6.1. Use I18n.t with the full key, e.g. I18n.t("spree.free").') if defined?(Spree::Deprecation)

      I18n.t(key, **options.symbolize_keys, scope: [:spree, *options[:scope]].uniq)
    end
    alias t translate

    # Locales Spree ships translations for and the app allows
    # (+config.i18n.available_locales+), plus English and the app's default and
    # current locale.
    #
    # @return [Array<Symbol>]
    def available_locales
      allowed = Array(Rails.application.config.i18n.available_locales).map(&:to_sym)
      locales = allowed.empty? ? SHIPPED_LOCALES.dup : SHIPPED_LOCALES & allowed
      locales << :en
      locales << I18n.locale
      locales << Rails.application.config.i18n.default_locale

      locales.uniq.compact
    end

    # Base languages of {available_locales}, e.g. "pt" for "pt-BR".
    #
    # @return [Array<String>]
    def available_languages
      available_locales.map { |locale| Spree::Locale.new(code: locale).language_code }.uniq
    end
  end
end
