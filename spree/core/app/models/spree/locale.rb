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

    # Display name, e.g. "English", "Deutsch". Falls back to the code for an
    # unknown locale.
    # @return [String]
    def name
      code = self.code.to_s

      if I18n.exists?('spree.i18n.this_file_language', locale: code, fallback: false)
        return normalize_name(Spree.t('i18n.this_file_language', locale: code))
      end

      if defined?(SpreeI18n::Locale) && (name = SpreeI18n::Locale.local_language_name(code))
        return normalize_name(name)
      end

      return 'English' if code == 'en'

      code
    end

    # Select label, e.g. "EN — English".
    # @return [String]
    def label
      upper = code.to_s.upcase
      return upper if name.blank? || name.casecmp?(code.to_s)

      "#{upper} — #{name}"
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
      code.to_s.downcase.tr('_', '-').split('-').first
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

    private

    # Strip a trailing " (CODE)" suffix from Spree I18n locale labels. Uses
    # plain string ops rather than a regex to avoid polynomial backtracking on
    # adversarial input (ReDoS).
    def normalize_name(name)
      name = name.to_s.rstrip
      return name unless name.end_with?(')')

      open_paren = name.rindex('(')
      return name unless open_paren

      name[0...open_paren].rstrip
    end
  end
end
