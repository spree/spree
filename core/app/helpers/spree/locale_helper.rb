module Spree
  module LocaleHelper
    def all_locales_options
      supported_locales_for_all_stores.map { |locale| locale_presentation(locale) }
    end

    def available_locales_options
      available_locales.map { |locale| locale_presentation(locale) }
    end

    def locale_presentation(locale)
      if defined?(SpreeI18n)
        [Spree.t('i18n.this_file_language', locale: locale), locale]
      else
        locale.to_s == 'en' ? ['English (US)', :en] : [locale, locale]
      end
    end
  end
end
