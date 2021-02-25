module Spree
  module LocaleHelper
    def all_locales_options
      convert_symbols_to_string = supported_locales_for_all_stores.map { |locale| locale.to_s }
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



[["Ukrainian (UK)", "uk"], ["Español (es-CL)", "es-CL"], ["Čeština (CS)", "cs"], ["Slovenščina (sl-SL)", "sl-SI"], ["Norsk (NB)", "nb"], ["Deutsch (de-CH)", "de-CH"], ["ภาษาไทย (TH)", "th"], ["Belarusian (BE)", "be"], ["Català (CA)", "ca"], ["Português (pt-BR)", "pt-BR"], ["Български (BG)", "bg"], ["Español (ES)", "es"], ["한국어 (KO)", "ko"], ["Danish (DA)", "da"], ["Suomi (FI)", "fi"], ["Indonesian (ID)", "id"], ["ភាសាខ្មែរ (KM)", "km"], ["Romanian (RO)", "ro"], ["Slovenčina (SK)", "sk"], ["Português (PT)", "pt"], ["Eesti keel (ET)", "et"], ["Deutsch (DE)", "de"], ["Italiano (IT)", "it"], ["Polski (PL)", "pl"], ["Greek (GR)", "gr"], ["فارسی (FA)", "fa"], ["Svenska (SE)", "sv"], ["日本語 (JA)", "ja"], ["English (en-GB)", "en-GB"], ["Español (es-EC)", "es-EC"], ["Russian (RU)", "ru"], ["English (en-IN)", "en-IN"], ["کردی (KU)", "ku"], ["Français (FR)", "fr"], ["繁體中文 (zh-TW)", "zh-TW"], ["Latvijas (LV)", "lv"], ["English (en-NZ)", "en-NZ"], ["English (en-AU)", "en-AU"], ["Arabic (AR)", "ar"], ["Lietuvių (LT)", "lt"], ["Español (es-MX)", "es-MX"], ["Türkçe (TR)", "tr"], ["tiếng Việt (VN)", "vi"], ["中文 简体 (zh-CN)", "zh-CN"], ["Nederlands (NL)", "nl"], ["English (US)", "en"], ["English (US)", "az"], ["English (US)", "hu"], ["English (US)", "el"], ["English (US)", "zh-YUE"], ["Español (ES)", "es-CO"], ["Italiano (IT)", "it-CH"], ["English (US)", "ml"], ["English (US)", "or"], ["Español (ES)", "es-NI"], ["English (US)", "en-ZA"], ["English (US)", "en-CA"], ["English (US)", "mn"], ["English (US)", "tl"], ["Español (ES)", "es-AR"], ["Français (FR)", "fr-CA"], ["Español (ES)", "es-US"], ["English (US)", "lo"], ["English (US)", "mk"], ["English (US)", "oc"], ["English (US)", "bs"], ["English (US)", "uz"], ["Deutsch (DE)", "de-AT"], ["English (US)", "ne"], ["English (US)", "rm"], ["English (US)", "gl"], ["English (US)", "kn"], ["English (US)", "is"], ["English (US)", "eu"], ["English (US)", "he"], ["English (US)", "hr"], ["English (US)", "en-IE"], ["English (US)", "sl"], ["English (US)", "pa"], ["English (US)", "sw"], ["Español (ES)", "es-PE"], ["Español (ES)", "es-ES"], ["English (US)", "hi"], ["English (US)", "eo"], ["English (US)", "zh-HK"], ["English (US)", "sq"], ["English (US)", "ka"], ["English (US)", "hi-IN"], ["Deutsch (DE)", "de-DE"], ["English (US)", "sr"], ["Español (ES)", "es-PA"], ["Français (FR)", "fr-FR"], ["Español (ES)", "es-419"], ["English (US)", "el-CY"], ["English (US)", "af"], ["English (US)", "cy"], ["English (US)", "ms"], ["Español (ES)", "es-CR"], ["English (US)", "lb"], ["English (US)", "mg"], ["Español (ES)", "es-VE"], ["English (US)", "te"], ["Svenska (SE)", "sv-SE"], ["English (US)", "en-US"], ["Hello world", "ta"], ["English (US)", "ur"], ["Français (FR)", "fr-CH"], ["English (US)", "nn"], ["English (US)", "en-CY"], ["English (US)", "mr-IN"], ["English (US)", "bn"], ["English (US)", "tt"], ["English (US)", "wo"], ["English (US)", "ug"], ["English (US)", "no"], ["Português (PT)", "pt-PT"]]
