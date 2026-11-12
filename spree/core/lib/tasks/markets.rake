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
          default_locale: Spree::Locales.listed(iso_country&.languages_official&.first) ||
                          Spree::Locales.listed(store.read_attribute(:default_locale)) || 'en',
          default: true,
          countries: countries
        )

        store.update_column(:checkout_zone_id, nil) if checkout_zone_id

        puts "  Created market '#{market.name}' with #{countries.size} countries for store '#{store.name}' (#{store.code})"
      end
    end

    desc "Set each market's tax_inclusive from whether its tax rates were included in the price"
    task backfill_tax_inclusive: :environment do
      # A rate with no store is one spree:backfill_tax_store_ids has not bound
      # yet, and a market decided without it would be decided on part of its rates.
      if Spree::TaxRate.with_deleted.where(store_id: nil).where.not(included_in_price: nil).exists?
        abort '  Some tax rates have no store yet. Run spree:backfill_tax_store_ids first, then run this again.'
      end

      updated = 0
      mixed = []

      Spree::Store.find_each do |store|
        # Each rate's old flag is read once and then cleared, so a re-run finds
        # nothing to read and cannot undo a market the merchant changed since.
        legacy_rates = Spree::TaxRate.with_deleted.where(store_id: store.id).where.not(included_in_price: nil)
        next unless legacy_rates.exists?

        ActiveRecord::Base.transaction do
          store.markets.includes(:market_countries).find_each do |market|
            # A rate with no country taxes every market's countries.
            conventions = legacy_rates.where(deleted_at: nil, country_code: market.country_codes + [nil]).
                          distinct.pluck(:included_in_price)
            next if conventions.empty?

            if conventions.size > 1
              mixed << market
              next
            end
            next if market.tax_inclusive == conventions.first

            market.update_columns(tax_inclusive: conventions.first, updated_at: Time.current)
            updated += 1
          end

          legacy_rates.update_all(included_in_price: nil)
          store.touch
        end
      end

      puts "  Set tax_inclusive on #{updated} market(s) from their tax rates."

      mixed.each do |market|
        puts "  ! Left '#{market.name}' (store #{market.store.code}) unchanged: some of its rates were included in " \
             "the price and some added on top. Set whether its prices include tax in the dashboard."
      end
    end
  end
end
