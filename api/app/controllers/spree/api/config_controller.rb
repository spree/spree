module Spree
  module Api
    class ConfigController < Spree::Api::BaseController
      def money
        render json: {
          symbol: ::Money.new(1, Spree::Config[:currency]).symbol,
          symbol_position: Spree::Config[:currency_symbol_position],
          no_cents: Spree::Config[:hide_cents],
          decimal_mark: Spree::Config[:currency_decimal_mark],
          thousands_separator: Spree::Config[:currency_thousands_separator]
        }
      end

      def show
        render json: { default_country_id: Spree::Config[:default_country_id] }
      end
    end
  end
end