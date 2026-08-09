module Spree
  module Seeds
    # Shopify-style delivery defaults per store: a Domestic zone (the store's
    # own country) and an International zone (everywhere else), each carrying
    # a basic flat-rate method so a fresh store can check out immediately.
    class DeliveryZones
      prepend Spree::ServiceModule::Base

      DOMESTIC_AMOUNT = 5
      INTERNATIONAL_AMOUNT = 20

      def call
        Spree::Store.includes(:default_country).find_each do |store|
          domestic_country = store.default_country
          next if domestic_country.nil?

          profile = store.default_delivery_profile || Spree::DeliveryProfiles::Shipping.create!(store: store, name: 'General', default: true)

          domestic = store.delivery_zones.where(name: 'Domestic').first_or_create! do |zone|
            zone.description = domestic_country.name
            zone.delivery_profile = profile
          end
          domestic.members.where(member_type: 'country', country: domestic_country).first_or_create!

          international = store.delivery_zones.where(name: 'International').first_or_create! do |zone|
            zone.description = 'Everywhere else'
            zone.delivery_profile = profile
          end
          add_country_members(international, Spree::Country.where.not(id: domestic_country.id))

          create_method(store, 'Standard', domestic, DOMESTIC_AMOUNT)
          create_method(store, 'International Shipping', international, INTERNATIONAL_AMOUNT)
        end
      end

      private

      def add_country_members(zone, countries)
        existing_ids = zone.members.where(member_type: 'country').pluck(:country_id)
        new_ids = countries.ids - existing_ids
        return if new_ids.empty?

        rows = new_ids.map do |country_id|
          {
            delivery_zone_id: zone.id,
            member_type: 'country',
            country_id: country_id,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
        Spree::DeliveryZoneMember.insert_all(rows)
      end

      def create_method(store, name, zone, amount)
        store.delivery_methods.where(name: name).first_or_create! do |delivery_method|
          delivery_method.calculator = Spree::Calculator::Shipping::FlatRate.new(
            preferences: { amount: amount, currency: store.default_currency }
          )
          delivery_method.delivery_profile = zone.delivery_profile
          delivery_method.delivery_zone = zone
        end
      end
    end
  end
end
