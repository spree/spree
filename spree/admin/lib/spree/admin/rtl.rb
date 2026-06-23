module Spree
  module Admin
    # Detects right-to-left locales for the legacy admin UI layout direction
    # (`<html dir="rtl">`). Admin-only — the React dashboard handles RTL itself
    # via i18next, so this lives in the admin gem rather than core.
    module Rtl
      # ISO 639-1 language codes that use right-to-left scripts.
      RTL_LANGUAGE_CODES = %w[ar he fa ur yi].freeze

      module_function

      # @param locale [String, Symbol]
      # @return [Boolean]
      def rtl_locale?(locale = I18n.locale)
        language_code = locale.to_s.tr('_', '-').split('-', 2).first
        RTL_LANGUAGE_CODES.include?(language_code)
      end

      # @param locale [String, Symbol]
      # @return [String] "rtl" or "ltr"
      def html_dir(locale = I18n.locale)
        rtl_locale?(locale) ? 'rtl' : 'ltr'
      end
    end
  end
end
