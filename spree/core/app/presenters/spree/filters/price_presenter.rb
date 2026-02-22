module Spree
  module Filters
    class PricePresenter
      def initialize(amount:, currency:)
        Spree::Deprecation.warn('Spree::Filters::PricePresenter is deprecated and will be removed in Spree 5.5.')
        @amount = amount.to_i
        @currency = currency
      end

      def to_i
        amount
      end

      def to_s
        Spree::Money.new(amount, currency: currency, no_cents_if_whole: true).to_s
      end

      private

      attr_reader :amount, :currency
    end
  end
end
