namespace :spree do
  namespace :markets do
    desc 'Migrate checkout zones to markets and nullify checkout_zone_id'
    task migrate_checkout_zones: :environment do
      Spree::Store.find_each do |store|
        next if store.markets.exists?

        checkout_zone_id = store.read_attribute(:checkout_zone_id)
        zone = Spree::Zone.find_by(id: checkout_zone_id) if checkout_zone_id

        countries = if zone
                      zone.country_list.to_a
                    else
                      default_country = Spree::Country.find_by(id: store.read_attribute(:default_country_id))
                      default_country ? [default_country] : []
                    end

        if countries.empty?
          puts "  Skipping store '#{store.name}' (#{store.code}) — no countries to migrate"
          next
        end

        primary_country = countries.first
        iso_country = ISO3166::Country[primary_country.iso] if primary_country

        market = store.markets.create!(
          name: primary_country&.name || 'Default',
          currency: iso_country&.currency_code || store.read_attribute(:default_currency) || 'USD',
          default_locale: iso_country&.languages_official&.first || store.read_attribute(:default_locale) || 'en',
          default: true,
          countries: countries
        )

        store.update_column(:checkout_zone_id, nil) if checkout_zone_id

        puts "  Created market '#{market.name}' with #{countries.size} countries for store '#{store.name}' (#{store.code})"
      end
    end
  end
end
