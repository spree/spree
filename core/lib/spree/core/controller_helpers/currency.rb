module Spree
  module Core
    module ControllerHelpers
      module Currency
        extend ActiveSupport::Concern

        included do
          if defined?(helper_method)
            helper_method :supported_currencies
            helper_method :supported_currencies_for_all_stores
            helper_method :current_currency
            helper_method :supported_currency?
            helper_method :currency_param
          end
        end

        # Returns the currently selected currency.
        # @return [String] the currently selected currency, eg. `USD`
        def current_currency
          @current_currency ||= begin
            currency = if defined?(session) && session.key?(:currency) && supported_currency?(session[:currency])
                         session[:currency]
                       elsif params[:currency].present? && supported_currency?(params[:currency])
                         params[:currency]
                       elsif current_store.present?
                         current_store.default_currency
                       else
                         Spree::Store.default.default_currency
                       end&.upcase
            Spree::Current.currency = currency
            currency
          end
        end

        # Returns the list of supported currencies for the current store.
        # @return [Array<Money::Currency>] the list of supported currencies
        def supported_currencies
          @supported_currencies ||= current_store&.supported_currencies_list
        end

        # Returns the list of supported currencies for all stores.
        # @return [Array<String>] the list of supported currencies, eg. `["USD", "EUR"]`
        def supported_currencies_for_all_stores
          @supported_currencies_for_all_stores ||= begin
            (
              Spree::Store.pluck(:supported_currencies).map { |c| c&.split(',') }.flatten + Spree::Store.pluck(:default_currency)
            ).
              compact.uniq.map { |code| ::Money::Currency.find(code.strip) }
          end
        end

        # Checks if the given currency is supported.
        # @param currency_iso_code [String] the ISO code of the currency, eg. `USD`
        # @return [Boolean] `true` if the currency is supported, `false` otherwise
        def supported_currency?(currency_iso_code)
          return false if supported_currencies.nil?

          supported_currencies.map(&:iso_code).include?(currency_iso_code.upcase)
        end

        # Returns the currency parameter from the request.
        # @return [String] the currency parameter, eg. `USD`
        def currency_param
          return if current_currency == current_store.default_currency

          current_currency
        end
      end
    end
  end
end
