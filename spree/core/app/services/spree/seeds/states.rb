require 'carmen'

module Spree
  module Seeds
    class States
      prepend Spree::ServiceModule::Base

      EXCLUDED_US_STATES = ['UM', 'AS', 'MP', 'VI', 'PR', 'GU'].freeze
      EXCLUDED_CN_STATES = ['HK', 'MO', 'TW'].freeze

      def call
        Spree::Country.where(states_required: true).each do |country|
          # Match on ISO code, not name: Spree stores official ISO-3166 names
          # ("United States of America") while Carmen uses common ones
          # ("United States"), and `named` is an exact match — so a name lookup
          # silently skipped the US, leaving it with no states at all.
          carmen_country = Carmen::Country.coded(country.iso) || Carmen::Country.named(country.name)
          next unless carmen_country

          states = carmen_country.subregions.flat_map do |subregion|
            if carmen_country.alpha_2_code == 'US'
              # Produces 50 states, one postal district (Washington DC)
              # and 3 APO's as you would expect to see on any good U.S. states list.
              next [] if EXCLUDED_US_STATES.include?(subregion.code)

              state_level(country, subregion)
            elsif carmen_country.alpha_2_code == 'CA' || carmen_country.alpha_2_code == 'MX'
              # Force Canada and Mexico to use state-level data import from Carmen Gem
              # else we pull in a subset of provinces that are not common at checkout.
              state_level(country, subregion)
            elsif carmen_country.alpha_2_code == 'CN'
              # Removes 3 "States" from that list that are also listed as Countries,
              # Hong Kong, Taiwan and Macao
              next [] if EXCLUDED_CN_STATES.include?(subregion.code)

              state_level(country, subregion)
            elsif subregion.subregions?
              province_level(country, subregion)
            else
              state_level(country, subregion)
            end
          end

          # One upsert per country rather than one per subregion.
          upsert_states(states)
        end
      end

      protected

      def state_level(country, subregion)
        [{ name: subregion.name, abbr: subregion.code, country_id: country.id }]
      end

      def province_level(country, subregion)
        subregion.subregions.map do |province|
          { name: province.name, abbr: province.code, country_id: country.id }
        end
      end

      # Seeds are re-run on every deploy, so this has to converge rather than
      # duplicate: `[country_id, abbr]` is unique, and a name change upstream
      # updates the existing row instead of adding a second one.
      def upsert_states(states)
        states = states.uniq { |state| [state[:country_id], state[:abbr]] }.reject { |state| state[:abbr].blank? }
        return if states.empty?

        now = Time.current
        opts = { update_only: %i[name] }
        # MySQL infers the conflict target from the table's unique constraints
        # and rejects an explicit +unique_by+; PostgreSQL/SQLite require it.
        opts[:unique_by] = %i[country_id abbr] unless mysql_adapter?

        Spree::State.upsert_all(states.map { |state| state.merge(created_at: now, updated_at: now) }, **opts)
      end

      def mysql_adapter?
        ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
      end
    end
  end
end
