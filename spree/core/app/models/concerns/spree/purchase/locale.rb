module Spree
  module Purchase
    module Locale
      extend ActiveSupport::Concern

      included do
        validates :locale, presence: true
        validate :locale_must_be_supported_by_store

        before_validation :ensure_locale
      end

      def ensure_locale
        return if locale.present?

        self.locale = Spree::Current.locale.presence || market&.default_locale
      end

      # Validates that the order's locale is within the store's supported locales.
      # Mirrors currency_must_be_supported_by_store.
      def locale_must_be_supported_by_store
        return if locale.blank? || store.blank?

        unless store.supported_locales_list.include?(locale)
          errors.add(:locale, :locale_not_supported_by_store, message: Spree.t(:locale_not_supported_by_store))
        end
      end
    end
  end
end
