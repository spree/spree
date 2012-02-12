require 'active_record/fixtures'

fixtures_dir = File.expand_path('../../../../../db/default', __FILE__)
ActiveRecord::Fixtures.create_fixtures(fixtures_dir, ['spree/countries', 'spree/zones', 'spree/zone_members', 'spree/states', 'spree/roles'])