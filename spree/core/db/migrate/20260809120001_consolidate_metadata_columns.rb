class ConsolidateMetadataColumns < ActiveRecord::Migration[7.2]
  # Records which tables this migration renamed, so `down` reverses exactly those.
  # Dropped on the way back down.
  CONSOLIDATED_TABLES_REGISTRY = :spree_consolidated_metadata_tables

  # The merge lives here rather than in the upgrade rake task because the manifest
  # runs AFTER db:migrate (see upgrade.rake and the CLI's upgrade command) — a
  # merge step scheduled there would find public_metadata already dropped and
  # silently lose whatever it held.
  def up
    tables = legacy_tables
    return if tables.empty?

    create_table CONSOLIDATED_TABLES_REGISTRY, if_not_exists: true do |t|
      t.string :table_name, null: false
    end

    tables.each do |table_name|
      merge_public_metadata_into_private(table_name)

      rename_column table_name, :private_metadata, :metadata
      remove_column table_name, :public_metadata

      connection.exec_insert(
        "INSERT INTO #{connection.quote_table_name(CONSOLIDATED_TABLES_REGISTRY)} (table_name) " \
        "VALUES (#{connection.quote(table_name)})"
      )
    end
  end

  # Restores the column shape, NOT the original split of values. The merge is
  # one-way: once public keys are folded into `metadata` there is no record of
  # which side they came from, and keeping a shadow copy of a column being deleted
  # would defeat the consolidation. Rolling back therefore returns every value
  # under `private_metadata` and leaves `public_metadata` empty — code that reads
  # the public side sees nothing.
  #
  # Set FORCE_METADATA_ROLLBACK=true to accept that and proceed.
  def down
    tables = consolidated_tables

    if tables.any? && ENV['FORCE_METADATA_ROLLBACK'] != 'true'
      raise ActiveRecord::IrreversibleMigration,
            'Rolling back would restore the public_metadata column empty: the merge into ' \
            'metadata is one-way and the original split is not recoverable. Re-run with ' \
            'FORCE_METADATA_ROLLBACK=true to restore the column shape and accept the loss.'
    end

    tables.each do |table_name|
      rename_column table_name, :metadata, :private_metadata

      change_table table_name do |t|
        if t.respond_to?(:jsonb)
          t.jsonb :public_metadata
        else
          t.json :public_metadata
        end
      end
    end

    drop_table CONSOLIDATED_TABLES_REGISTRY, if_exists: true
  end

  private

  # Copies public_metadata into private_metadata, private winning on key collision
  # since that is the side the `metadata` accessor and the API have always read.
  # Row by row: merging two JSON documents in one UPDATE would need a different
  # expression per adapter, and this runs once.
  def merge_public_metadata_into_private(table_name)
    quoted_table = connection.quote_table_name(table_name)
    rows = connection.select_all(
      "SELECT id, public_metadata, private_metadata FROM #{quoted_table} WHERE public_metadata IS NOT NULL"
    )

    rows.each do |row|
      public_metadata = parse_json(row['public_metadata'])
      next if public_metadata.blank?

      merged = public_metadata.merge(parse_json(row['private_metadata']))

      connection.exec_update(
        "UPDATE #{quoted_table} SET private_metadata = #{connection.quote(merged.to_json)} " \
        "WHERE id = #{connection.quote(row['id'])}"
      )
    end
  end

  # Anything that isn't a Hash — an array or scalar an application stored in the
  # untyped column, unparseable text — becomes {} rather than aborting the migration.
  def parse_json(value)
    parsed = value.is_a?(String) ? (JSON.parse(value) rescue nil) : value

    parsed.is_a?(Hash) ? parsed : {}
  end

  # Tables still carrying the legacy pair. The columns are the whole signal: a table
  # born with a single `metadata` column has no `public_metadata`, so it can never
  # match. A table that somehow has all three is skipped rather than guessed at —
  # renaming onto an existing `metadata` would fail anyway.
  def legacy_tables
    connection.tables.select do |table_name|
      column_exists?(table_name, :private_metadata) &&
        column_exists?(table_name, :public_metadata) &&
        !column_exists?(table_name, :metadata)
    end
  end

  # Tables this migration consolidated, identified by the marker it wrote on the way
  # up rather than by shape. Shape alone cannot distinguish a table we renamed from
  # one that was born with a single `metadata` column — both end up with exactly that
  # column — and reversing the latter would break models that have always read it.
  def consolidated_tables
    return [] unless connection.table_exists?(CONSOLIDATED_TABLES_REGISTRY)

    connection.select_values(
      "SELECT table_name FROM #{connection.quote_table_name(CONSOLIDATED_TABLES_REGISTRY)}"
    ).select { |table_name| column_exists?(table_name, :metadata) }
  end
end
