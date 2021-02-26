module Spree
  module LocaleHelper
    def all_locales_options
      convert_symbols_to_string = supported_locales_for_all_stores.map(&:to_s)
      removed_upcased_duplicates = convert_symbols_to_string.delete_if { |locale| capitalized?(locale) }
      unique_locale_set = removed_upcased_duplicates.uniq

      unique_locale_set.sort.map { |locale| locale_presentation(locale) }
    end

    def available_locales_options
      available_locales.map { |locale| locale_presentation(locale) }
    end

    def supported_locales_options
      return if current_store.nil?

      current_store.supported_locales_list.map { |locale| locale_presentation(locale) }
    end

    def locale_presentation(locale)
      if I18n.exists?('spree.i18n.this_file_language', locale: locale, fallback: false)
        [Spree.t("i18n.this_file_language", locale: locale) + " (#{locale})", locale.to_s]
      else
        []
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
