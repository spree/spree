module Spree
  module Purchase
    module Market
      extend ActiveSupport::Concern

      included do
        belongs_to :market, class_name: 'Spree::Market'

        attr_accessor :skip_market_resolution

        before_validation :ensure_market_presence
        before_validation :resolve_market_from_currency, if: -> { persisted? && currency_changed? && !skip_market_resolution }

        # Guards against a client forcing an off-channel market_id through the
        # API. Skipped when either side is missing so jobs and imports without
        # channel context keep working (docs/plans/6.0-channel-markets.md).
        validate :market_served_by_channel, if: -> { market_id.present? && channel_id.present? }
      end

      def ensure_market_presence
        return if market.present?

        # The ambient market counts only when this channel sells into it.
        # Spree::Current.market falls back to the STORE default, so taking it
        # unconditionally would hand a restricted channel a market its own
        # validation then rejects.
        ambient = Spree::Current.market
        ambient = nil if ambient && channel && !channel.serves_market?(ambient)

        self.market = ambient || channel&.resolved_default_market || store&.default_market
      end

      # When currency changes, auto-resolve the matching market (mirrors Order).
      def resolve_market_from_currency
        return unless store&.markets&.exists?
        return if market&.currency == currency

        candidates = channel ? channel.allowed_markets : store.markets
        resolved = candidates.find_by(currency: currency)
        self.market = resolved if resolved
      end

      private

      def market_served_by_channel
        return if channel.serves_market?(market)

        errors.add(:market, :not_served_by_channel)
      end
    end
  end
end
