module Spree
  module Stores
    # Creates the per-store defaults whose shape depends on where the shop is:
    # the default market, the warehouse, the delivery zones and their methods,
    # and pickup. The seeds cannot build these, because when they run nobody
    # has said which country the shop sells from yet — so they are built here,
    # from the merchant's answer, rather than seeded as US and rewritten later.
    #
    # Two callers only (docs/plans/6.0-store-context-and-first-run-setup.md):
    # the first-run setup endpoint, and the env-credential branch of
    # Spree::Seeds::AdminUser. Never wire this to a settings screen — run
    # against a configured store it reads as a data reset.
    class ProvisionDefaults
      prepend Spree::ServiceModule::Base

      DOMESTIC_AMOUNT = 5
      INTERNATIONAL_AMOUNT = 20

      # @param store [Spree::Store] the store to provision, already persisted
      # @param country [Spree::Country] where the shop ships from
      # @param locale [String, nil] storefront locale; defaults to the
      #   country's own language when Spree translates it, then English
      # @param currency [String, nil] ISO 4217 code; defaults to the country's
      #   own currency. Merchants who ship from one country and price in
      #   another currency pass it explicitly.
      # @return [Spree::Store] the store, reloaded
      def call(store:, country:, locale: nil, currency: nil)
        @store = store
        @country = country
        @currency = resolve_currency(currency, country)
        @locale = resolve_locale(locale, country)

        ApplicationRecord.transaction do
          update_default_market
          provision_stock_location
          provision_delivery_zones
          provision_pickup
          restate_seeded_calculators
        end

        store.reload
      end

      private

      attr_reader :store, :country, :currency, :locale

      # An unknown code falls back rather than raising: callers validate before
      # calling, and a seed reading STORE_CURRENCY from the environment should
      # not fail an install over a typo.
      def resolve_currency(requested, country)
        found = ::Money::Currency.find(requested.to_s.strip) if requested.present?

        found&.iso_code || country.default_currency.presence || 'USD'
      end

      # An explicit locale is honored as given — a host app may ship its own
      # translations. Only the *derived* default is filtered: falling back to
      # a country's official language that Spree has no strings for would set
      # a storefront to a language with nothing behind it, and it is not one
      # the setup screen ever offers. Installs without spree_i18n know only
      # English, so filtering there would flatten every country to it.
      def resolve_locale(requested, country)
        return requested if requested.present?

        derived = country.default_locale.presence
        return 'en' if derived.blank?

        translated = Spree.available_locales.map { |locale| locale.to_s.split('-').first }.uniq
        return derived if translated.size <= 1 || translated.include?(derived)

        (country.official_locales & translated).first || 'en'
      end

      # The store's own country/currency/locale columns are not the source of
      # truth once a market exists — Spree::Stores::Markets reads through the
      # default market — so the market is what gets written. The columns are
      # kept in step for the stores that have no market yet.
      def update_default_market
        store.update_columns(
          default_country_code: country.iso,
          default_currency: currency,
          default_locale: locale,
          updated_at: Time.current
        )
        adopt_admin_locale
        store.association(:default_market).reset

        market = store.default_market
        return if market.nil?

        market.name = country.name
        market.currency = currency
        market.default_locale = locale
        market.country_codes = [country.iso]
        market.save!

        store.association(:default_market).reset
      end

      # The merchant is asked for one language, and expects it to apply to the
      # back office as well as the storefront — those are separate settings,
      # and setting only the storefront one leaves the dashboard in English.
      # This is the store-wide default, the weakest of the three tiers: an
      # admin's own choice still wins, and Settings can change it later.
      #
      # Written even when the dashboard ships no translations for it. Whether
      # a language has an admin bundle is the dashboard's own fact, not one
      # this side can check without going stale — an unsupported code is
      # ignored there and falls back to English, and starts working on its
      # own if a bundle lands later.
      def adopt_admin_locale
        return if store.preferred_admin_locale.present?

        store.preferred_admin_locale = locale
        store.save!
      end

      # Match on identity alone: folding the other attributes into the finder
      # made re-running fail once anything edited them.
      def provision_stock_location
        # first_party, so a seller who happened to name a location the same
        # thing is never adopted as the store's own.
        location = store.stock_locations.first_party.
                   where(name: Spree.t(:default_stock_location_name)).first_or_initialize
        location.propagate_all_variants = false if location.new_record?
        location.country_code = country.iso
        if location.persisted? && location.will_save_change_to_country_code?
          location.assign_attributes(address1: nil, address2: nil, city: nil,
                                     state_code: nil, state_name: nil,
                                     zipcode: nil, phone: nil)
        end
        location.active = true
        location.default = true
        location.save!
      end

      # Shopify-style defaults: the store's own country ships cheaply,
      # everywhere else ships at the international rate.
      def provision_delivery_zones
        profile = store.default_delivery_profile ||
                  Spree::DeliveryProfiles::Shipping.create!(store: store, name: 'General', default: true)

        domestic = store.delivery_zones.where(name: 'Domestic').first_or_initialize
        domestic.description = country.name
        domestic.delivery_profile = profile
        domestic.save!
        sync_zone_countries(domestic, [country.iso])

        international = store.delivery_zones.where(name: 'International').first_or_initialize
        international.description = 'Everywhere else'
        international.delivery_profile = profile
        international.save!
        sync_zone_countries(international, Spree::Country.all.map(&:iso) - [country.iso])

        create_method('Standard', domestic, DOMESTIC_AMOUNT)
        create_method('International Shipping', international, INTERNATIONAL_AMOUNT)
      end

      # Rewrites membership so re-running with a different country cannot
      # leave the previous country's rows behind on both zones.
      def sync_zone_countries(zone, isos)
        existing = zone.members.where(member_type: 'country')
        existing.where.not(country_code: isos).delete_all

        missing = isos - existing.reload.pluck(:country_code)
        return if missing.empty?

        now = Time.current
        Spree::DeliveryZoneMember.insert_all(
          missing.map do |iso|
            {
              delivery_zone_id: zone.id,
              member_type: 'country',
              country_code: iso,
              created_at: now,
              updated_at: now
            }
          end
        )
      end

      def create_method(name, zone, amount)
        delivery_method = store.delivery_methods.where(name: name).first_or_initialize
        delivery_method.delivery_profile = zone.delivery_profile
        delivery_method.delivery_zone = zone
        delivery_method.calculator ||= Spree::Calculator::Shipping::FlatRate.new
        delivery_method.calculator.preferences = { amount: amount, currency: currency }
        delivery_method.save!
      end

      # Collection at a merchant counter. Rides the store's default profile
      # (the same physical goods ship or get collected) with no zone — pickup
      # has no destination, only an origin, and the Pickup provider decides
      # which locations can hand goods over.
      def provision_pickup
        profile = store.default_delivery_profile
        return if profile.nil?

        # A counter to collect from is what makes pickup real, so the store's
        # default location opens for collection unless one already has.
        if store.stock_locations.first_party.where(pickup_enabled: true).none?
          store.stock_locations.first_party.find_by(default: true)&.update!(pickup_enabled: true)
        end
        return if store.stock_locations.first_party.where(pickup_enabled: true).none?

        delivery_method = store.delivery_methods.where(name: Spree.t('pickup.store_pickup')).first_or_initialize
        delivery_method.delivery_profile = profile
        delivery_method.storefront_visible = true
        delivery_method.fulfillment_provider = 'Spree::FulfillmentProvider::Pickup'
        delivery_method.calculator ||= Spree::Calculator::Shipping::FlatRate.new
        delivery_method.calculator.preferences = { amount: 0, currency: currency }
        delivery_method.save!

        # No configured counters means every pickup-enabled location, which
        # is what a fresh store wants; seeding the links would freeze the set.
      end

      # Methods seeded before the country was known (digital delivery) captured
      # the store's then-current currency as their calculator default, so they
      # would still quote in dollars on a store that turned out to sell from
      # Zurich. Only the seeded zero-amount defaults are restated — a merchant's
      # own priced methods are never rewritten.
      def restate_seeded_calculators
        store.delivery_methods.includes(:calculator).find_each do |delivery_method|
          calculator = delivery_method.calculator
          next unless calculator.respond_to?(:preferred_currency)
          next if calculator.preferred_currency == currency
          next unless calculator.preferences[:amount].to_f.zero?

          calculator.update!(preferences: calculator.preferences.merge(currency: currency))
        end
      end
    end
  end
end
