module Spree
  module Purchase
    module Market
      extend ActiveSupport::Concern

      # The including model declares `belongs_to :market` itself: an order
      # reads a deleted market back, a cart does not.
      included do
        attr_accessor :skip_market_resolution

        before_validation :ensure_market_presence
        before_validation :resolve_market_from_currency, if: -> { persisted? && currency_changed? && !skip_market_resolution }
      end

      def ensure_market_presence
        self.market ||= Spree::Current.market || store&.default_market
      end

      # When currency changes, auto-resolve the matching market (mirrors Order).
      def resolve_market_from_currency
        return unless store&.markets&.exists?
        return if market&.currency == currency

        resolved = store.markets.find_by(currency: currency)
        self.market = resolved if resolved
      end
    end
  end
end
