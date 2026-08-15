module Spree
  # Copies country and state foreign keys onto the ISO string columns that
  # replace them. Driven by `rake spree:upgrade:migrate_country_state_codes`.
  #
  # Reads the legacy tables through throwaway model classes: Spree::Country and
  # Spree::State stop being ActiveRecord models in 6.0, but this task has to
  # keep working against a database where their tables are still present.
  #
  # Resumable by construction. Every table is filled with one UPDATE ... FROM
  # scoped to the rows whose ISO column is still null, so the work outstanding
  # is a query rather than tracked state. An interrupted run picks up where it
  # stopped, and re-running when nothing is left is a no-op.
  class CountryStateCodeMigrator
    COUNTRIES_TABLE = 'spree_countries'.freeze
    STATES_TABLE = 'spree_states'.freeze

    # @return [Hash, nil] rows filled per table, or nil when there is nothing to migrate
    def call
      return nil unless connection.table_exists?(COUNTRIES_TABLE)

      {
        addresses: backfill_addresses,
        delivery_zone_members: backfill_delivery_zone_members,
        market_countries: backfill_market_countries,
        stock_locations: backfill_stock_locations,
        stores: backfill_stores
      }
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    def quote(value)
      connection.quote_table_name(value)
    end

    # Country ISO for every row whose FK still resolves. The state branch is
    # separate because a row can carry a country without a state.
    def backfill_country_code(table, foreign_key: 'country_id', column: 'country_code')
      return 0 unless connection.column_exists?(table, column)

      update_from(
        table: table,
        source: COUNTRIES_TABLE,
        assignments: { column => 'iso' },
        foreign_key: foreign_key,
        guard: column
      )
    end

    def backfill_addresses
      filled = backfill_country_code(Spree::Address.table_name)
      filled + backfill_state_code(Spree::Address.table_name)
    end

    def backfill_delivery_zone_members
      table = Spree::DeliveryZoneMember.table_name
      filled = backfill_country_code(table)
      filled += copy_state_code(table)
      # A state member records no country of its own, so its country comes from
      # the state's — without it, coverage queries could not tell which country
      # an abbreviation belongs to. Runs before normalization, which needs both
      # halves to resolve a code.
      filled += backfill_country_code_from_state(table)
      normalize_state_codes(table)
      filled
    end

    def backfill_market_countries
      backfill_country_code(Spree::MarketCountry.table_name)
    end

    def backfill_stock_locations
      table = Spree::StockLocation.table_name
      backfill_country_code(table) + backfill_state_code(table)
    end

    def backfill_stores
      backfill_country_code(
        Spree::Store.table_name,
        foreign_key: 'default_country_id',
        column: 'default_country_code'
      )
    end

    # Copies the code across, then normalizes it: the pre-6.0 seed wrote codes
    # ISO has since retired (Odisha as OR, Gauteng as GT) and occasionally in
    # lower case, while matching compares stored codes verbatim. Left as-is,
    # a backfilled address would silently stop matching zones written with the
    # successor code.
    def backfill_state_code(table)
      return 0 unless connection.column_exists?(table, 'state_code')

      filled = copy_state_code(table)
      normalize_state_codes(table)
      filled
    end

    # The verbatim copy, split out so callers that still have to derive the
    # country can normalize afterwards rather than before.
    def copy_state_code(table)
      return 0 unless connection.column_exists?(table, 'state_code')

      update_from(
        table: table,
        source: STATES_TABLE,
        assignments: { 'state_code' => 'abbr' },
        foreign_key: 'state_id',
        guard: 'state_code'
      )
    end

    # Rewrites any code that isn't already the canonical one for its country.
    def normalize_state_codes(table)
      quoted_table = quote(table)
      rows = connection.select_rows(<<~SQL.squish)
        SELECT DISTINCT country_code, state_code FROM #{quoted_table}
        WHERE state_code IS NOT NULL AND country_code IS NOT NULL
      SQL

      rows.each do |country_code, state_code|
        canonical = Spree::IsoData.subdivision_code(country_code, state_code)
        next if canonical.blank? || canonical == state_code

        connection.update(<<~SQL.squish)
          UPDATE #{quoted_table} SET state_code = #{connection.quote(canonical)}
          WHERE country_code = #{connection.quote(country_code)}
            AND state_code = #{connection.quote(state_code)}
        SQL
      end
    end

    # Country ISO for state members, resolved through the state's own country.
    def backfill_country_code_from_state(table)
      quoted_table = quote(table)
      states = quote(STATES_TABLE)
      countries = quote(COUNTRIES_TABLE)

      sql = <<~SQL.squish
        UPDATE #{quoted_table}
        SET country_code = (
          SELECT #{countries}.iso
          FROM #{states}
          INNER JOIN #{countries} ON #{countries}.id = #{states}.country_id
          WHERE #{states}.id = #{quoted_table}.state_id
        )
        WHERE #{quoted_table}.country_code IS NULL
          AND #{quoted_table}.state_id IS NOT NULL
      SQL

      connection.update(sql)
    end

    # A correlated subquery rather than UPDATE ... FROM: the latter's syntax
    # differs across PostgreSQL, MySQL and SQLite, and this shape runs on all
    # three. Row counts here are small — a few hundred thousand addresses at
    # most — so the simpler portable form is worth more than the speed.
    def update_from(table:, source:, assignments:, foreign_key:, guard:)
      return 0 unless connection.table_exists?(source)

      quoted_table = quote(table)
      quoted_source = quote(source)

      sets = assignments.map do |target_column, source_column|
        <<~SQL.squish
          #{target_column} = (
            SELECT #{quoted_source}.#{source_column}
            FROM #{quoted_source}
            WHERE #{quoted_source}.id = #{quoted_table}.#{foreign_key}
          )
        SQL
      end

      sql = <<~SQL.squish
        UPDATE #{quoted_table}
        SET #{sets.join(', ')}
        WHERE #{quoted_table}.#{guard} IS NULL
          AND #{quoted_table}.#{foreign_key} IS NOT NULL
      SQL

      connection.update(sql)
    end
  end
end
