module Spree
  module Stores
    module Markets
      extend ActiveSupport::Concern

      included do
        has_many :markets, class_name: 'Spree::Market', dependent: :destroy
      end

      # Returns the default market for this store
      # @return [Spree::Market, nil]
      def default_market
        @default_market ||= Spree::Market.default_for_store(self)
      end

      # Returns the default country, derived from the default market
      # @return [Spree::Country, nil]
      def default_country
        if has_markets?
          default_market&.default_country
        else
          super
        end
      end

      # Returns the default country ID, derived from the default market
      # @return [Integer, nil]
      def default_country_id
        if has_markets?
          default_country&.id
        else
          read_attribute(:default_country_id)
        end
      end

      # Returns the default locale, delegating to the default market when markets exist
      # Falls back to the store's own default_locale column
      # @return [String, nil]
      def default_locale
        if has_markets?
          default_market&.default_locale || read_attribute(:default_locale)
        else
          read_attribute(:default_locale)
        end
      end

      # Returns the default currency, delegating to the default market when markets exist
      # Falls back to the store's own default_currency column
      # @return [String, nil]
      def default_currency
        if has_markets?
          default_market&.currency || read_attribute(:default_currency)
        else
          read_attribute(:default_currency)
        end
      end

      # Returns the market that contains the given country
      # @param country [Spree::Country]
      # @return [Spree::Market, nil]
      def market_for_country(country)
        Spree::Market.for_country(country, store: self)
      end

      # Returns countries from all markets as an ActiveRecord relation
      # @return [ActiveRecord::Relation<Spree::Country>]
      def countries_from_markets
        Spree::Country.where(id: Spree::MarketCountry.where(market_id: markets.ids).select(:country_id)).order(:name)
      end

      # Returns the countries available for checkout, derived from markets
      # @return [Array<Spree::Country>]
      def countries_available_for_checkout
        @countries_available_for_checkout = begin
          if has_markets?
            markets.flat_map(&:countries).uniq.sort_by(&:name)
          else
            Spree::Country.all.to_a
          end
        end
      end

      # Returns supported currencies derived from markets, falling back to store attributes
      # @return [Array<Money::Currency>]
      def supported_currencies_list
        @supported_currencies_list ||= if has_markets?
                                         markets.pluck(:currency).uniq.map do |code|
                                           ::Money::Currency.find(code)
                                         end.compact.sort_by { |c| c.iso_code == default_currency ? 0 : 1 }
                                       else
                                         legacy_supported_currencies_list
                                       end
      end

      # Returns supported locales derived from markets, falling back to store attributes
      # @return [Array<String>]
      def supported_locales_list
        @supported_locales_list ||= if has_markets?
                                      (markets.flat_map(&:supported_locales_list) << default_locale).compact.uniq.sort
                                    else
                                      legacy_supported_locales_list
                                    end
      end

      private

      def has_markets?
        @has_markets ||= persisted? && (markets.loaded? ? markets.any? : markets.exists?)
      end

      def legacy_supported_currencies_list
        ([default_currency] + read_attribute(:supported_currencies).to_s.split(',')).uniq.map(&:to_s).map do |code|
          ::Money::Currency.find(code.strip)
        end.compact.sort_by { |currency| currency.iso_code == default_currency ? 0 : 1 }
      end

      def legacy_supported_locales_list
        (read_attribute(:supported_locales).to_s.split(',') << default_locale).compact.uniq.sort
      end
    end
  end
end
