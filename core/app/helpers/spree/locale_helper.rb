module Spree
  module LocaleHelper
    def all_locales_options
      supported_locales_for_all_stores.map { |locale| locale_presentation(locale) }
    end

    def available_locales_options
      available_locales.map { |locale| locale_presentation(locale) }
    end

    def supported_locales_options
      return if current_store.nil?

      current_store.supported_locales_list.map { |locale| locale_presentation(locale) }
    end

    def locale_presentation(locale)
      formatted_locale = locale.to_s

      if I18n.t('spree.is_fully_translated', locale: formatted_locale, fallback: false) == true
        ["#{Spree::Store.locale_language_name(formatted_locale, current_locale).to_s} (#{formatted_locale})", formatted_locale]
      else
        []
      end
    end

    def should_render_locale_dropdown?
      return false if current_store.nil?

      current_store.supported_locales_list.size > 1
    end
  end
end
