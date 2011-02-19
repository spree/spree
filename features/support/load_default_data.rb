DatabaseCleaner.clean

# load default data for tests
require 'active_record/fixtures'
fixtures_dir = File.expand_path('../../../core/db/default', __FILE__)
Fixtures.create_fixtures(fixtures_dir, ['countries', 'zones', 'zone_members', 'states', 'roles'])
PaymentMethod::Check.create(:name => 'Check' )

# use transactions for faster tests
#DatabaseCleaner.strategy = :transaction
