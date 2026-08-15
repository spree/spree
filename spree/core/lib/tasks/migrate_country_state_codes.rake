# Defined here rather than in lib/spree/core/ — this is a one-release upgrade
# step that dies with the country and state tables in 6.1, not engine
# infrastructure. Same placement as Spree::ReturnsMigrator in a sibling task.

require 'spree/country_state_code_migrator'

namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Copies country and state foreign keys onto the ISO code columns that
      replace them (docs/plans/6.0-drop-country-state-models.md).

      Countries and states stop being database records in Spree 6; addresses,
      delivery zone members, market countries, stock locations and stores name
      them by ISO code instead. This fills those columns from the existing
      foreign keys.

      Delivery zone members that name a state also gain their country, which
      the state row used to supply. A subdivision code is only unique within
      its country, so the pair is what makes a member resolvable on its own.

      Resumable by construction: each table is filled with a single statement
      scoped to the rows whose ISO column is still empty, so an interrupted
      run picks up where it stopped and re-running when nothing is left is a
      no-op — no cursor to track, no state to reset.

      Run after spree:migrate_zones_to_delivery_zones, so converted zone
      members are present to be backfilled.
    DESC
    task migrate_country_state_codes: :environment do
      result = Spree::CountryStateCodeMigrator.new.call

      if result.nil?
        puts '  spree_countries not found — nothing to migrate.'
        next
      end

      result.each do |table, filled|
        puts "  #{table}: filled #{filled} row(s)."
      end
    end
  end
end
