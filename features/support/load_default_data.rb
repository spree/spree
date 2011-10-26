DatabaseCleaner.clean

# load default data for tests
require 'active_record/fixtures'
fixtures_dir = File.expand_path('../../../core/db/default/', __FILE__)
ActiveRecord::Fixtures.create_fixtures(fixtures_dir, ['spree/countries', 'spree/zones', 'spree/zone_members', 'spree/states', 'spree/roles'])
Spree::PaymentMethod::Check.create(:name => 'Check')

# use transactions for faster tests
#DatabaseCleaner.strategy = :transaction
