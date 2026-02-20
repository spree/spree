namespace :spree do
  namespace :markets do
    desc 'Create default markets for stores that do not have any markets'
    task create_defaults: :environment do
      Spree::Store.find_each do |store|
        next if store.markets.exists?

        zone = store.checkout_zone
        unless zone
          puts "  Skipping store '#{store.name}' (#{store.code}) — no checkout zone configured"
          next
        end

        market = store.markets.create!(
          name: 'Default',
          currency: store.default_currency,
          zone: zone,
          default_locale: store.default_locale || 'en',
          supported_locales: store.read_attribute(:supported_locales),
          default: true
        )

        puts "  Created default market '#{market.name}' for store '#{store.name}' (#{store.code})"
      end
    end
  end
end
