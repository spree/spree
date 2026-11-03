module Spree
  module TestingSupport
    # A Ruby stand-in for the configurator's store defaults
    # (packages/config/templates), for specs that need a provisioned store and
    # have no Admin API to deploy them through. It builds only what Ruby code
    # reads back; the templates stay the one source of truth.
    module StoreDefaults
      # @param store [Spree::Store]
      # @return [Spree::Store]
      def self.provision(store)
        country = store.default_country_code || 'US'
        general = store.default_delivery_profile

        store.stock_locations.first_party.find_or_create_by!(name: 'Shop location') do |location|
          location.country_code = country
          location.default = true
          location.pickup_enabled = true
          location.propagate_all_variants = false
        end

        { 'Domestic' => [country], 'International' => (%w[US CA GB DE] - [country]) }.each do |name, codes|
          zone = store.delivery_zones.find_or_create_by!(name: name) { |new_zone| new_zone.delivery_profile = general }
          codes.each { |code| zone.members.find_or_create_by!(member_type: 'country', country_code: code) }
        end

        digital = Spree::DeliveryProfiles::Digital.find_by(store: store) ||
                  Spree::DeliveryProfiles::Digital.create!(store: store, name: 'Digital')
        store.product_types.find_or_create_by!(name: 'Default')
        store.product_types.find_or_create_by!(name: 'Digital') { |type| type.delivery_profile = digital }

        store.tax_categories.find_or_create_by!(name: 'Default') { |category| category.is_default = true }
        store.customer_groups.find_or_create_by!(name: 'Wholesale')
        store.payment_methods.find_or_create_by!(type: 'Spree::PaymentMethod::StoreCredit') do |method|
          method.name = 'Store Credit'
          method.active = true
        end

        store.reload
      end
    end
  end
end
