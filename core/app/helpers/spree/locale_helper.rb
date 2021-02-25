module Spree
  module LocaleHelper
    def all_locales_options
      convert_symbols_to_string = supported_locales_for_all_stores.map(&:to_s)
      removed_upcased_duplicates = convert_symbols_to_string.delete_if { |locale| capitalized?(locale) }
      unique_locale_set = removed_upcased_duplicates.uniq

      unique_locale_set.map { |locale| locale_presentation(locale) }
    end

    def available_locales_options
      available_locales.map { |locale| locale_presentation(locale) }
    end

    def supported_locales_options
      return if current_store.nil?

      current_store.supported_locales_list.map { |locale| locale_presentation(locale) }
    end

    def locale_presentation(locale)
      if locale == 'en'
        ['English (Default)', 'en']
      elsif locale == 'en-US'
        ['English (US)', 'en-US']
      elsif I18n.t('spree.i18n.this_file_language', locale: locale) != 'English (US)'
        [Spree.t('i18n.this_file_language', locale: locale), locale.to_s]
      else
        ["(#{locale.to_s.upcase})", locale.to_s]
      end
    end

    def should_render_locale_dropdown?
      return false if current_store.nil?

      current_store.supported_locales_list.size > 1
    end

    private

    def capitalized?(str)
      ('A'..'Z').include?(str[0])
    end
  end
end
