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

      # Returns the market that contains the given country
      # @param country [Spree::Country]
      # @return [Spree::Market, nil]
      def market_for_country(country)
        Spree::Market.for_country(country, store: self)
      end

      # Returns the countries available for checkout, derived from markets or checkout_zone
      # @return [Array<Spree::Country>]
      def countries_available_for_checkout
        @countries_available_for_checkout ||= Rails.cache.fetch(countries_available_for_checkout_cache_key) do
          if markets.any?
            markets.flat_map(&:countries).uniq.sort_by(&:name)
          else
            (checkout_zone.try(:country_list) || Spree::Country.all).to_a
          end
        end
      end

      # Returns supported currencies derived from markets, falling back to store attributes
      # @return [Array<Money::Currency>]
      def supported_currencies_list
        @supported_currencies_list ||= if markets.any?
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
        @supported_locales_list ||= if markets.any?
                                      markets.flat_map(&:supported_locales_list).uniq.sort
                                    else
                                      legacy_supported_locales_list
                                    end
      end

      private

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
