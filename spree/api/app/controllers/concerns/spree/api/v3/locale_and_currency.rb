module Spree
  module Api
    module V3
      # Handles locale, currency, and market resolution for API v3 controllers.
      #
      # This concern is fully self-contained and does not depend on
      # +Spree::Core::ControllerHelpers::Locale+ or +Spree::Core::ControllerHelpers::Currency+.
      #
      # Resolution order:
      # 1. Market is resolved from +x-spree-country+ header (sets +Spree::Current.market+)
      # 2. Locale is resolved: +x-spree-locale+ header > +params[:locale]+ > +Spree::Current.locale+ (market -> store fallback)
      # 3. Currency is resolved: +x-spree-currency+ header > +params[:currency]+ > +Spree::Current.currency+ (market -> store fallback)
      # 4. Mobility fallback locale is configured for the current store
      module LocaleAndCurrency
        extend ActiveSupport::Concern

        included do
          before_action :set_market_from_country
          before_action :set_locale
          before_action :set_currency
          before_action :set_fallback_locale
        end

        protected

        # Returns the current locale for this request.
        #
        # Priority: x-spree-locale header > params[:locale] > Spree::Current.locale (market -> store fallback)
        #
        # @return [String] the locale code, e.g. +"en"+, +"fr"+
        def current_locale
          @current_locale ||= begin
            locale = locale_from_header || locale_from_params
            locale.to_s if locale.present? && supported_locale?(locale)
          end || Spree::Current.locale
        end

        # Returns the current currency for this request.
        #
        # Priority: x-spree-currency header > params[:currency] > Spree::Current.currency (market -> store fallback)
        #
        # @return [String] the currency ISO code, e.g. +"USD"+, +"EUR"+
        def current_currency
          @current_currency ||= begin
            currency = currency_from_header || currency_from_params
            currency = currency&.upcase
            currency if currency.present? && supported_currency?(currency)
          end || Spree::Current.currency
        end

        # Returns the default locale, delegating to +Spree::Current.locale+
        # which falls back through market -> store.
        #
        # @return [String] the default locale code
        def default_locale
          Spree::Current.locale
        end

        # Returns the list of supported locale codes for the current store.
        #
        # When markets are configured, this aggregates locales from all markets.
        #
        # @return [Array<String>] supported locale codes
        def supported_locales
          @supported_locales ||= current_store&.supported_locales_list
        end

        # Checks if the given locale is supported by the current store.
        #
        # @param locale_code [String, nil] the locale code to check
        # @return [Boolean]
        def supported_locale?(locale_code)
          return false if supported_locales.nil?

          supported_locales.include?(locale_code&.to_s)
        end

        # Returns the list of supported currencies for the current store.
        #
        # When markets are configured, this aggregates currencies from all markets.
        #
        # @return [Array<Money::Currency>] supported currencies
        def supported_currencies
          @supported_currencies ||= current_store&.supported_currencies_list
        end

        # Checks if the given currency ISO code is supported by the current store.
        #
        # @param currency_iso_code [String, nil] the currency ISO code to check, e.g. +"USD"+
        # @return [Boolean]
        def supported_currency?(currency_iso_code)
          return false if supported_currencies.nil?

          supported_currencies.map(&:iso_code).include?(currency_iso_code&.upcase)
        end

        # Finds a record using the given block, falling back to the store's default locale
        # if the record is not found in the current locale.
        #
        # Used for slug/permalink lookups where translated slugs may not exist in all locales.
        #
        # @yield the block that performs the lookup
        # @return [ActiveRecord::Base] the found record
        # @raise [ActiveRecord::RecordNotFound] if not found in any locale
        def find_with_fallback_default_locale(&block)
          result = begin
            block.call
          rescue ActiveRecord::RecordNotFound => _e
            nil
          end

          result || Mobility.with_locale(current_store.default_locale) { block.call }
        end

        private

        # Sets +I18n.locale+ and +Spree::Current.locale+ from the resolved locale.
        def set_locale
          Spree::Current.locale = current_locale
          I18n.locale = current_locale
        end

        # Sets +Spree::Current.currency+ from the resolved currency.
        def set_currency
          Spree::Current.currency = current_currency
        end

        # Configures Mobility fallback locales for the current store.
        #
        # This runs after market resolution so fallbacks are aware of the store's
        # full locale configuration.
        def set_fallback_locale
          return unless current_store.present?

          Spree::Locales::SetFallbackLocaleForStore.new.call(store: current_store)
        end

        # Reads the locale from the +x-spree-locale+ request header.
        #
        # @return [String, nil]
        def locale_from_header
          request.headers['x-spree-locale'].presence
        end

        # Reads the currency from the +x-spree-currency+ request header.
        #
        # @return [String, nil]
        def currency_from_header
          request.headers['x-spree-currency'].presence
        end

        # Reads the locale from request params.
        #
        # @return [String, nil]
        def locale_from_params
          params[:locale].presence
        end

        # Reads the currency from request params.
        #
        # @return [String, nil]
        def currency_from_params
          params[:currency].presence
        end

        # Resolves the market from the +x-spree-country+ header or +params[:country]+.
        #
        # When a matching market is found, it is set on +Spree::Current.market+,
        # which influences the default locale and currency fallbacks.
        def set_market_from_country
          country_iso = request.headers['x-spree-country'].presence || params[:country].presence
          return unless country_iso

          country = Spree::Country.find_by(iso: country_iso.upcase)
          return unless country

          market = current_store&.market_for_country(country)
          return unless market

          Spree::Current.market = market
        end
      end
    end
  end
end
