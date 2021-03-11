module Spree
  module LocaleHelper
    require 'twitter_cldr'

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

      if Spree::Config.only_show_languages_marked_as_active
        if I18n.t('spree.active_language', locale: locale, fallback: false) == true
          [locale_language_name(formatted_locale, use_active_locale), formatted_locale]
        else
          []
        end
      else
        [locale_language_name(formatted_locale, use_active_locale), formatted_locale]
      end
    end

    def should_render_locale_dropdown?
      return false if current_store.nil?

      current_store.supported_locales_list.size > 1
    end

    def locale_language_name(locale, use_active_locale)
      locale_as_symbol = locale.to_sym
      falback_locale = locale.to_s.slice(0..1).to_sym

      used_default_locale = if use_active_locale
                              I18n.locale.to_sym
                            else
                              locale.to_sym
                            end

      if I18n.exists?("spree.language_name_overide.#{locale}", locale: used_default_locale.to_s, fallback: false)
        return I18n.t("spree.language_name_overide.#{locale}", locale: used_default_locale.to_s)
      end

      lang_name = locale_as_symbol.localize(used_default_locale).as_language_code || falback_locale.localize(used_default_locale).as_language_code
      "#{lang_name.to_s.capitalize} (#{locale})".strip
    end
  end
end
