module Spree
  module LocaleHelper
    def all_locales_options(use_active_locale = false)
      supported_locales_for_all_stores.map { |locale| locale_presentation(locale, use_active_locale) }
    end

    def available_locales_options
      available_locales.map { |locale| locale_presentation(locale) }
    end

    def supported_locales_options
      return if current_store.nil?

      current_store.supported_locales_list.map { |locale| locale_presentation(locale) }
    end

    def locale_presentation(locale, use_active_locale = false)
      formatted_locale = locale.to_s

      [Spree::Store.locale_language_name(formatted_locale, use_active_locale), formatted_locale]
    end

    def should_render_locale_dropdown?
      return false if current_store.nil?

      current_store.supported_locales_list.size > 1
    end
  end
end
