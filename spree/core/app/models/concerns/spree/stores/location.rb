module Spree
  module Stores
    # Where a store sells from, and whether it has the defaults it needs to
    # trade. Both are answered once, at first-run setup or by the seed on a
    # scripted install; everything shaped by the answer (warehouse, delivery
    # zones, pickup, the parcel box) is deployed afterwards by the
    # configurator's store defaults (docs/plans/6.0-cli-configurator.md).
    module Location
      extend ActiveSupport::Concern

      # Moves the store and its default market to a country. Never wire this
      # to a settings screen: a merchant changing country later edits the
      # market directly, and the defaults built for the old country stay.
      #
      # @param country [Spree::Country] where the shop sells from
      # @param locale [String, nil] storefront locale; defaults to the
      #   country's own language when Spree translates it, then English
      # @param currency [String, nil] ISO 4217 code; defaults to the country's
      #   own currency. An unknown code falls back rather than raising, so a
      #   seed reading STORE_CURRENCY does not fail an install over a typo.
      # @return [Spree::Store] the store, reloaded
      def relocate(country:, locale: nil, currency: nil)
        currency = relocation_currency(currency, country)
        locale = relocation_locale(locale, country)

        ApplicationRecord.transaction do
          # The columns are not the source of truth once a market exists — the
          # store reads through its default market — but they are kept in
          # step for the stores that have none yet.
          update_columns(
            default_country_code: country.iso,
            default_currency: currency,
            default_locale: locale,
            updated_at: Time.current
          )
          adopt_admin_locale(locale)
          relocate_default_market(country, currency, locale)
        end

        reload
      end

      # Whether the store defaults were deployed: the default warehouse is the
      # first thing they create, and nothing else creates it.
      #
      # @return [Boolean]
      def provisioned?
        stock_locations.first_party.where(default: true).exists?
      end

      private

      def relocation_currency(requested, country)
        found = ::Money::Currency.find(requested.to_s.strip) if requested.present?

        found&.iso_code || country.default_currency.presence || 'USD'
      end

      # An explicit locale is honored as given — a host app may ship its own
      # translations. Only the derived default is filtered: falling back to a
      # country's official language that Spree has no strings for would set a
      # storefront to a language with nothing behind it. Installs without
      # spree_i18n know only English, so filtering there would flatten every
      # country to it.
      def relocation_locale(requested, country)
        return requested if requested.present?

        derived = country.default_locale.presence
        return 'en' if derived.blank?

        translated = Spree.available_locales.map { |locale| locale.to_s.split('-').first }.uniq
        return derived if translated.size <= 1 || translated.include?(derived)

        (country.official_locales & translated).first || 'en'
      end

      # The merchant is asked for one language and expects it in the back
      # office too. This is the weakest of the three tiers: an admin's own
      # choice still wins, and Settings can change it later.
      def adopt_admin_locale(locale)
        return if preferred_admin_locale.present?

        self.preferred_admin_locale = locale
        save!
      end

      def relocate_default_market(country, currency, locale)
        association(:default_market).reset
        market = default_market
        return if market.nil?

        market.name = country.name
        market.currency = currency
        market.default_locale = locale
        market.country_codes = [country.iso]
        market.save!

        association(:default_market).reset
      end
    end
  end
end
