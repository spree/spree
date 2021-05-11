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
      if I18n.exists?('spree.i18n.this_file_language', locale: locale)
        [locale_full_name(locale), locale.to_s]
      else
        locale.to_s == 'en' ? ['English (US)', 'en'] : [locale, locale.to_s]
      end
    end

    def locale_full_name(locale)
      Spree.t('i18n.this_file_language', locale: locale)
    end

    def should_render_locale_dropdown?
      return false if current_store.nil?

      current_store.supported_locales_list.size > 1
    end
  end
end
