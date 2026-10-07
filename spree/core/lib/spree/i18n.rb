require 'i18n'

module Spree
  class << self
    # @deprecated Use +I18n.t+ with the full key, e.g. +I18n.t('spree.free')+.
    #   Will be removed in Spree 6.1.
    def translate(key, options = {})
      Spree::Deprecation.warn('Spree.t is deprecated and will be removed in Spree 6.1. Use I18n.t with the full key, e.g. I18n.t("spree.free").') if defined?(Spree::Deprecation)

      I18n.t(key, **options.symbolize_keys, scope: [:spree, *options[:scope]])
    end
    alias t translate

    # Locales Spree ships translations for, plus the app's default and current locale.
    #
    # @return [Array<Symbol>]
    def available_locales
      locales = Dir[File.expand_path('../../config/locales/*.yml', __dir__)].map { |file| File.basename(file, '.yml').to_sym }
      locales << :en
      locales << I18n.locale
      locales << Rails.application.config.i18n.default_locale

      locales.uniq.compact
    end
  end
end
