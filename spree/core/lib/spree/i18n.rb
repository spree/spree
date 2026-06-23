require 'i18n'
require 'active_support/core_ext/array/extract_options'
require 'action_view'

module Spree
  class TranslationHelperWrapper
    include ActionView::Helpers::TranslationHelper
  end

  class << self
    # Add spree namespace and delegate to Rails TranslationHelper for some nice
    # extra functionality. e.g return reasonable strings for missing translations
    def translate(key, options = {})
      options[:scope] = [*options[:scope]].unshift(:spree).uniq

      TranslationHelperWrapper.new.translate(key, **options)
    end

    def available_locales
      locales = defined?(SpreeI18n) ? SpreeI18n::Locale.all.map(&:to_sym) : []
      locales.concat(registered_available_locales)
      locales << :en
      locales << I18n.locale
      locales << Rails.application.config.i18n.default_locale

      locales.uniq.compact
    end

    # Register a locale shipped by a Spree engine (e.g. admin-only translations).
    # @param locale [String, Symbol]
    def register_available_locale(locale)
      registered_available_locales << locale.to_sym
    end

    def registered_available_locales
      @registered_available_locales ||= []
    end

    alias t translate
  end
end
