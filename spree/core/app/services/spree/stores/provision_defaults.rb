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
      # @param country [Spree::Country] where the shop sells from
      # @param locale [String, nil] storefront locale; defaults to the
      #   country's own language, then English
      # @return [Spree::Store] the store, reloaded
      def call(store:, country:, locale: nil)
        @store = store
        @country = country
        @currency = country.default_currency.presence || 'USD'
        @locale = locale.presence || country.default_locale.presence || 'en'

        ApplicationRecord.transaction do
          update_default_market
          provision_stock_location
          provision_delivery_zones
          provision_pickup
        end

        store.reload
      end

      private

      attr_reader :store, :country, :currency, :locale

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

      # Match on identity alone: folding the other attributes into the finder
      # made re-running fail once anything edited them.
      def provision_stock_location
        location = store.stock_locations.where(name: Spree.t(:default_stock_location_name)).first_or_initialize
        location.propagate_all_variants = false if location.new_record?
        location.country_code = country.iso
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
        if store.stock_locations.where(pickup_enabled: true).none?
          store.stock_locations.find_by(default: true)&.update!(pickup_enabled: true)
        end
        return if store.stock_locations.where(pickup_enabled: true).none?

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
    end
  end
end
