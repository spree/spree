module Spree
  module Purchase
    module Currency
      extend ActiveSupport::Concern

      included do
        validates :currency, presence: true
        validate :currency_must_be_supported_by_store

        before_validation :ensure_currency
      end

      def currency_must_be_supported_by_store
        return if currency.blank? || store.blank?

        supported_codes = store.supported_currencies_list.map(&:iso_code)
        unless supported_codes.include?(currency)
          errors.add(:currency, :currency_not_supported_by_store, message: Spree.t(:currency_not_supported_by_store))
        end
      end

      def ensure_currency
        return if currency.present?

        self.currency = market&.currency
      end
    end
  end
end
