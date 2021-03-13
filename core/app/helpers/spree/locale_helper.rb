module Spree
  module LocaleHelper
    require 'twitter_cldr'

    def all_locales_options(set_locale = nil)
      supported_locales_for_all_stores.map { |locale| locale_presentation(locale, set_locale) }
    end

    def available_locales_options
      available_locales.map { |locale| locale_presentation(locale) }
    end

    def supported_locales_options
      return if current_store.nil?

      current_store.supported_locales_list.map { |locale| locale_presentation(locale) }
    end

    def locale_presentation(locale, set_locale = nil)
      formatted_locale = locale.to_s

      if Spree::Config.only_show_languages_marked_as_active
        if I18n.t('spree.active_language', locale: locale, fallback: false) == true
          [locale_language_name(formatted_locale, set_locale), formatted_locale]
        else
          []
        end
      else
        [locale_language_name(formatted_locale, set_locale), formatted_locale]
      end
    end

    def should_render_locale_dropdown?
      return false if current_store.nil?

      current_store.supported_locales_list.size > 1
    end

    # Returns a locale name in its native language, or a specified language.
    # The first argument passed is the locale of the language name that you require.
    # The optional second argument is the language you require the locale name returning in.
    #
    # ==== Examples
    #
    #   locale_language_name('de') #=> 'Deutsch (de)'
    #   locale_language_name('de', 'en' ) #=> 'German (de)'
    #   locale_language_name(:it, :de) #=> 'Italienisch (it)'
    #   locale_language_name('xx-XX') #=> '(xx-XX)'
    def locale_language_name(locale, set_locale = nil)
      locale_as_symbol = locale.to_sym
      falback_locale = locale.to_s.slice(0..1).to_sym

      used_locale = if set_locale
                      set_locale.to_s
                    else
                      locale.to_sym
                    end

      if I18n.exists?("spree.language_name_overide.#{locale}", locale: used_locale.to_s, fallback: false)
        return I18n.t("spree.language_name_overide.#{locale}", locale: used_locale.to_s)
      end

      lang_name = locale_as_symbol.localize(used_locale).as_language_code || falback_locale.localize(used_locale).as_language_code
      "#{lang_name.to_s.capitalize} (#{locale})".strip
    end
  end
end
