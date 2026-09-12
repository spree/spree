module Spree
  # Validates the locale codes a store or market persists.
  #
  # Request locales are already filtered by
  # +Spree::Api::V3::LocaleAndCurrency#supported_locale?+; stored settings were
  # not, and they are read back on every subsequent request.
  module LocaleSettings
    extend ActiveSupport::Concern

    included do
      validate :default_locale_is_a_known_code
      validate :supported_locales_are_known_codes
    end

    private

    # read_attribute, not the reader: Spree::Stores::Markets redirects
    # #default_locale to the default market, leaving this column unchecked.
    def default_locale_is_a_known_code
      code = read_attribute(:default_locale)
      return if code.blank? || Spree::Locales.known?(code)

      errors.add(:default_locale, :not_a_known_locale)
    end

    # Comma-separated column (see #supported_locales=), so not an inclusion.
    def supported_locales_are_known_codes
      codes = read_attribute(:supported_locales).to_s.split(',').map(&:strip).reject(&:blank?)
      unknown = codes.reject { |code| Spree::Locales.known?(code) }
      return if unknown.empty?

      errors.add(:supported_locales, :not_a_known_locale_list, codes: unknown.uniq.join(', '))
    end
  end
end
