module Spree
  module Core
    module ControllerHelpers
      module Currency
        extend ActiveSupport::Concern

        included do
          helper_method :supported_currencies
          helper_method :supported_currencies_for_all_stores
          helper_method :current_currency
          helper_method :supported_currency?
        end

        def current_currency
          # session support was previously in SpreeMultiCurrency so we would like
          # to keep it for now
          @current_currency ||= if defined?(session) && session.key?(:currency) && supported_currency?(session[:currency])
                                  session[:currency]
                                elsif params[:currency].present? && supported_currency?(params[:currency])
                                  params[:currency]
                                else
                                  current_store.default_currency
                                end
        end

        def supported_currencies
          @supported_currencies ||= current_store.supported_currencies_list
        end

        def supported_currencies_for_all_stores
          @supported_currencies_for_all_stores ||= begin
            (
              Spree::Store.pluck(:supported_currencies).map { |c| c&.split(',') }.flatten + Spree::Store.pluck(:default_currency)
            ).
              compact.uniq.map { |code| ::Money::Currency.find(code.strip) }
          end
        end

        def supported_currency?(currency_iso_code)
          supported_currencies.map(&:iso_code).include?(currency_iso_code)
        end
      end
    end
  end
end
