module Spree
  # Virtual model for a supported locale. Wraps a locale +code+ and exposes its
  # display name, layout direction, and whether it is a store's default — the
  # single home for that logic (RTL list, name resolution) instead of being
  # restated in serializers, helpers, and the admin RTL module.
  class Locale
    include ActiveModel::Model
    include Comparable

    # ISO 639-1 language codes that use right-to-left scripts.
    RTL_LANGUAGE_CODES = %w[ar he fa ur yi].freeze

    # @!attribute code
    #   @return [String] the locale code, e.g. "en", "pt-BR"
    attr_accessor :code

    # Localized display name, e.g. "English", "Deutsch".
    # @return [String]
    def name
      Spree::LocalizedNames.language_name(code)
    end

    # @return [Spree::Store] the current store
    def store
      @store ||= Spree::Store.current
    end

    # @return [Boolean] whether this is the store's default (source) locale
    def default?
      store.present? && code.to_s == store.default_locale.to_s
    end

    # @return [Boolean] whether the locale uses a right-to-left script
    def rtl?
      RTL_LANGUAGE_CODES.include?(language_code)
    end

    # @return [String] "rtl" or "ltr"
    def direction
      rtl? ? 'rtl' : 'ltr'
    end

    # The base ISO 639-1 language code, dropping any region (e.g. "pt-BR" → "pt").
    # @return [String]
    def language_code
      code.to_s.tr('_', '-').split('-', 2).first
    end

    def to_s
      code.to_s
    end

    # Compare/equality by code so a Locale slots into string-keyed collections
    # (e.g. `locale == "en"`, `[locale].sort`).
    def <=>(other)
      to_s <=> other.to_s
    end

    def eql?(other)
      other.is_a?(Spree::Locale) && code.to_s == other.code.to_s
    end

    def hash
      code.to_s.hash
    end
  end
end
