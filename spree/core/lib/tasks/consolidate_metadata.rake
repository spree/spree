module Spree
  module MetadataConsolidator
    # JSON columns come back as a Hash on some adapters and a String on others.
    # Anything that isn't a Hash — an array or scalar an application stored in the
    # untyped column, unparseable text — becomes {} rather than aborting the run.
    def self.parse(value)
      parsed = value.is_a?(String) ? (JSON.parse(value) rescue nil) : value

      parsed.is_a?(Hash) ? parsed : {}
    end
  end
end

namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Reports whether any table still carries the pre-6.0 public_metadata /
      private_metadata pair, and merges public_metadata into private_metadata if so.

      The 6.0 migration does this merge itself, before it drops the column, so a
      normal `db:migrate` needs nothing from this task. It exists for installs whose
      schema was changed out of band — a manually dropped column, a half-applied
      migration, an extension table that adopted the pair and was missed.

      Keys present in both columns keep the private value, matching the migration.
      Idempotent, and a no-op on an already-consolidated schema.
    DESC
    task consolidate_metadata: :environment do
      connection = ActiveRecord::Base.connection

      tables = connection.tables.select do |table_name|
        connection.column_exists?(table_name, :public_metadata) &&
          connection.column_exists?(table_name, :private_metadata)
      end

      if tables.empty?
        puts '  No table carries both metadata columns — nothing to do.'
        next
      end

      merged_total = 0

      tables.sort.each do |table_name|
        quoted_table = connection.quote_table_name(table_name)
        # Selected rather than filtered in SQL: PostgreSQL has no equality operator
        # for `json`, so `WHERE public_metadata <> '{}'` is not portable.
        rows = connection.select_all(
          "SELECT id, public_metadata, private_metadata FROM #{quoted_table} WHERE public_metadata IS NOT NULL"
        )

        merged_for_table = 0

        rows.each do |row|
          public_metadata = Spree::MetadataConsolidator.parse(row['public_metadata'])
          next if public_metadata.blank?

          merged = public_metadata.merge(Spree::MetadataConsolidator.parse(row['private_metadata']))

          connection.exec_update(
            "UPDATE #{quoted_table} SET private_metadata = #{connection.quote(merged.to_json)} " \
            "WHERE id = #{connection.quote(row['id'])}"
          )
          merged_for_table += 1
        end

        merged_total += merged_for_table
        puts "  #{table_name}: merged #{merged_for_table} row(s)." if merged_for_table.positive?
      end

      puts "  Done. Merged #{merged_total} row(s) across #{tables.size} table(s) still carrying both columns."
    end
  end
end
