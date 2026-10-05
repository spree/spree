module Spree
  module Purchase
    module Market
      extend ActiveSupport::Concern

      included do
        belongs_to :market, class_name: 'Spree::Market'

        attr_accessor :skip_market_resolution

        # Whether moving to another market drops a shipping address it does not
        # sell to (a cart) rather than refusing it (an order).
        class_attribute :drops_ship_address_on_market_change, instance_writer: false, default: false

        before_validation :ensure_market_presence
        before_validation :resolve_market_from_currency, if: :market_follows_currency?
        # Registered here so it runs before Addresses copies the shipping address onto billing.
        before_validation :drop_ship_address_outside_market, if: :drop_ship_address_outside_market?

        validate :ship_address_within_market, if: -> { market_reassigned? || ship_address_country_moved? }
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

      # @return [Boolean] whether saving will move the market to the one matching the new currency
      def market_follows_currency?
        persisted? && currency_changed? && !skip_market_resolution
      end

      # Settles the market the save would, for callers that act on it before saving.
      #
      # @return [void]
      def settle_market
        ensure_market_presence
        resolve_market_from_currency if market_follows_currency?
      end

      # A market sells only to its own countries, the default market included.
      #
      # @param address [Spree::Address, nil]
      # @return [Boolean] whether the market sells to the address's country
      def market_sells_to?(address)
        return true if address&.country_code.blank? || market.nil?

        market.country_codes.include?(address.country_code)
      end

      # @return [Boolean] whether the shipping address is in a country the market does not list
      def ship_address_outside_market?
        !market_sells_to?(ship_address)
      end

      # @return [String] what the buyer has to change, naming the country and the market
      def ship_address_outside_market_message
        Spree.t('checkout_requirements.ship_address_outside_market',
                country: ship_address.country_name || ship_address.country_code, market: market.name)
      end

      private

      def drop_ship_address_outside_market?
        drops_ship_address_on_market_change && will_save_change_to_market_id? && !ship_address_country_moved?
      end

      # Moving to another market, whether by market id, by currency or because
      # the old one was deleted, drops an address the new market does not sell
      # to. Only an address submitted outside the market is refused.
      def drop_ship_address_outside_market
        self.ship_address = nil if ship_address_outside_market?
      end

      # A record whose market was deleted gets the default one on its next
      # save; that fallback must not refuse an address nobody changed.
      def market_reassigned?
        market_id_in_database.present? && will_save_change_to_market_id?
      end

      # Compared by country rather than by address row, so correcting a typo on
      # an upgraded order whose address predates its market is not refused.
      def ship_address_country_moved?
        return false if ship_address.nil?
        unless ship_address.new_record? || will_save_change_to_ship_address_id?
          return ship_address.will_save_change_to_country_code? || ship_address_country_edited?
        end
        return true if ship_address_id_in_database.nil?

        ship_address.country_code != Spree::Address.where(id: ship_address_id_in_database).pick(:country_code)
      end

      def ship_address_within_market
        errors.add(:base, :ship_address_outside_market, message: ship_address_outside_market_message) if ship_address_outside_market?
      end
    end
  end
end
