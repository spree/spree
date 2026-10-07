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
                      # Countries are reference data in 6.0, so the legacy id
                      # is resolved against the table the upgrade keeps.
                      iso = ActiveRecord::Base.connection.select_value(
                        "SELECT iso FROM spree_countries WHERE id = #{ActiveRecord::Base.connection.quote(store.read_attribute(:default_country_id))}"
                      ) if store.read_attribute(:default_country_id)
                      default_country = Spree::Country.by_iso(iso) if iso
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
          countries: countries,
          # 'included' is the default for new markets only; an upgraded store keeps restating prices abroad.
          tax_display: 'dynamic'
        )

        store.update_column(:checkout_zone_id, nil) if checkout_zone_id

        puts "  Created market '#{market.name}' with #{countries.size} countries for store '#{store.name}' (#{store.code})"
      end
    end

    desc 'Set dynamic tax display on markets created before the setting existed'
    task backfill_tax_display: :environment do
      count = Spree::Market.with_deleted.where(tax_display: nil).in_batches.sum do |batch|
        batch.update_all(tax_display: 'dynamic')
      end

      puts count.zero? ? '  Nothing to backfill.' : "  Set dynamic tax display on #{count} market(s)."
    end
  end
end
