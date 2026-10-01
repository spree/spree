module Spree
  # What a store's published email template and its draft share: which
  # editable template they are, in which language, and the default they
  # started from.
  module EmailTemplateIdentity
    extend ActiveSupport::Concern

    # The version every language uses. Never NULL, so the unique index on
    # store, key and locale holds for it too.
    ANY_LOCALE = 'any'.freeze
    LOCALE_FORMAT = /\A(any|[a-z]{2,3}(-[A-Za-z0-9]{2,8})*)\z/

    included do
      include Spree::SingleStoreResource

      normalizes :locale, with: ->(locale) { locale.to_s.strip.presence || ANY_LOCALE }

      validates :key, presence: true, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id, :locale] }
      validates :locale, format: { with: LOCALE_FORMAT }
      validates :body, :base_body, presence: true
      validate :key_editable
      validate :locale_supported

      scope :for_key, ->(key, locale = ANY_LOCALE) { where(key: key, locale: locale) }
    end

    # @return [Spree::Emails::EditableTemplates::Definition, nil]
    def definition
      Spree.editable_email_templates[key]
    end

    # @return [Boolean] whether Spree's default changed since this version started from it
    # @param default [Spree::Emails::Template, nil] the current default
    def default_changed?(default)
      return false unless default

      default.body != base_body || default.subject.to_s != base_subject.to_s
    end

    private

    def key_editable
      errors.add(:key, :invalid) if key.present? && definition.nil?
    end

    def locale_supported
      return if locale == ANY_LOCALE || store.nil?

      errors.add(:locale, :inclusion) unless store.supported_locales_list.include?(locale)
    end
  end
end
