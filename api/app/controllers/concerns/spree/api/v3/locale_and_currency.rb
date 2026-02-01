module Spree
  module Api
    module V3
      module LocaleAndCurrency
        extend ActiveSupport::Concern

        included do
          before_action :set_locale_from_header
          before_action :set_currency_from_header
        end

        protected

        # Override current_locale to check header first
        def current_locale
          @current_locale ||= begin
            locale = locale_from_header || locale_from_params || default_locale
            locale.to_s if supported_locale?(locale)
          end || default_locale
        end

        # Override current_currency to check header first
        def current_currency
          @current_currency ||= begin
            currency = currency_from_header || currency_from_params || current_store&.default_currency
            currency = currency&.upcase
            supported_currency?(currency) ? currency : current_store&.default_currency
          end
        end

        private

        def set_locale_from_header
          I18n.locale = current_locale
        end

        def set_currency_from_header
          Spree::Current.currency = current_currency
        end

        def locale_from_header
          request.headers['x-spree-locale'].presence
        end

        def currency_from_header
          request.headers['x-spree-currency'].presence
        end

        def locale_from_params
          params[:locale].presence
        end

        def currency_from_params
          params[:currency].presence
        end
      end
    end
  end
end
